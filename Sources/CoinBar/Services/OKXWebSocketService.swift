import Foundation

protocol OKXWebSocketServiceDelegate: AnyObject {
    func webSocketService(_ service: OKXWebSocketService, didReceiveTicker ticker: Ticker)
    func webSocketServiceDidChangeStatus(_ service: OKXWebSocketService, connected: Bool)
}

final class OKXWebSocketService {
    weak var delegate: OKXWebSocketServiceDelegate?

    private var webSocketTask: URLSessionWebSocketTask?
    private var pingTimer: Timer?
    private var reconnectTimer: Timer?
    private var healthCheckTimer: Timer?
    private var subscribedInstIds: [String] = []
    private var isActive = false
    private var isReceiving = false
    private var lastReceiveTime: Date = .distantPast

    private let url = URL(string: "wss://ws.okx.com:8443/ws/v5/public")!
    private let session: URLSession

    private(set) var isConnected = false {
        didSet {
            if oldValue != isConnected {
                delegate?.webSocketServiceDidChangeStatus(self, connected: isConnected)
            }
        }
    }

    init() {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = false
        session = URLSession(configuration: config)
    }

    func connect(instIds: [String]) {
        isActive = true
        subscribedInstIds = instIds

        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        isReceiving = false
        reconnectTimer?.invalidate()

        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()

        subscribe(instIds: instIds)
        startPing()
        startHealthCheck()
        startReceive()
    }

    func disconnect() {
        isActive = false
        stopAllTimers()
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        isReceiving = false
        isConnected = false
    }

    func subscribe(instIds: [String]) {
        let args = instIds.map { ["channel": "tickers", "instId": $0] }
        let msg: [String: Any] = ["op": "subscribe", "args": args]
        send(json: msg)
    }

    private func send(json dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let text = String(data: data, encoding: .utf8) else { return }
        webSocketTask?.send(.string(text)) { _ in }
    }

    private func startPing() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.webSocketTask?.sendPing { error in
                if error != nil {
                    DispatchQueue.main.async {
                        self?.forceReconnect()
                    }
                }
            }
        }
    }

    private func startHealthCheck() {
        lastReceiveTime = Date()
        healthCheckTimer?.invalidate()
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            guard let self else { return }
            let elapsed = Date().timeIntervalSince(self.lastReceiveTime)
            if elapsed > 40 {
                DispatchQueue.main.async {
                    self.forceReconnect()
                }
            }
        }
    }

    private func startReceive() {
        guard !isReceiving else { return }
        isReceiving = true
        receive()
    }

    private func receive() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                self.isConnected = true
                self.lastReceiveTime = Date()

                switch message {
                case .string(let text):
                    self.handleText(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleText(text)
                    }
                @unknown default:
                    break
                }
                self.receive()

            case .failure(let error):
                self.isConnected = false
                self.isReceiving = false

                let nsError = error as NSError
                if nsError.domain == NSPOSIXErrorDomain && nsError.code == 57 {
                    return
                }

                self.scheduleReconnect()
            }
        }
    }

    private func handleText(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let arg = json["arg"] as? [String: Any],
              let channel = arg["channel"] as? String,
              channel == "tickers",
              let dataArray = json["data"] as? [[String: Any]],
              let first = dataArray.first,
              let ticker = Ticker.parse(json: first) else { return }

        DispatchQueue.main.async {
            self.delegate?.webSocketService(self, didReceiveTicker: ticker)
        }
    }

    private func forceReconnect() {
        guard isActive else { return }
        webSocketTask?.cancel(with: .abnormalClosure, reason: nil)
        webSocketTask = nil
        isReceiving = false
        scheduleReconnect()
    }

    private func scheduleReconnect() {
        guard isActive else { return }
        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { [weak self] _ in
            guard let self, self.isActive else { return }
            self.connect(instIds: self.subscribedInstIds)
        }
    }

    private func stopAllTimers() {
        pingTimer?.invalidate()
        pingTimer = nil
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
    }
}
