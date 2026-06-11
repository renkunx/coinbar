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
    private var subscribedInstIds: [String] = []
    private var isActive = false

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
        webSocketTask?.cancel()
        reconnectTimer?.invalidate()

        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()

        subscribe(instIds: instIds)
        startPing()
        receive()
    }

    func disconnect() {
        isActive = false
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        pingTimer?.invalidate()
        pingTimer = nil
        reconnectTimer?.invalidate()
        reconnectTimer = nil
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
            self?.webSocketTask?.sendPing { _ in }
        }
    }

    private func receive() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                self.isConnected = true
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
            case .failure:
                self.isConnected = false
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
              let first = dataArray.first else { return }

        guard let instId = arg["instId"] as? String,
              let lastStr = first["last"] as? String,
              let last = Double(lastStr),
              let open24hStr = first["open24h"] as? String,
              let open24h = Double(open24hStr) else { return }

        let sodUtc0: Double = {
            guard let s = first["sodUtc0"] as? String, let v = Double(s) else { return open24h }
            return v
        }()
        let sodUtc8: Double = {
            guard let s = first["sodUtc8"] as? String, let v = Double(s) else { return open24h }
            return v
        }()
        let high24h: Double = {
            guard let s = first["high24h"] as? String, let v = Double(s) else { return 0 }
            return v
        }()
        let low24h: Double = {
            guard let s = first["low24h"] as? String, let v = Double(s) else { return 0 }
            return v
        }()
        let vol24h: Double = {
            guard let s = first["vol24h"] as? String, let v = Double(s) else { return 0 }
            return v
        }()

        let ticker = Ticker(
            instId: instId,
            last: last,
            open24h: open24h,
            sodUtc0: sodUtc0,
            sodUtc8: sodUtc8,
            high24h: high24h,
            low24h: low24h,
            vol24h: vol24h
        )

        DispatchQueue.main.async {
            self.delegate?.webSocketService(self, didReceiveTicker: ticker)
        }
    }

    private func scheduleReconnect() {
        guard isActive else { return }
        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { [weak self] _ in
            guard let self, self.isActive else { return }
            self.connect(instIds: self.subscribedInstIds)
        }
    }
}
