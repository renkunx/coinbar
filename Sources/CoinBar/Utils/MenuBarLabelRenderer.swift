import SwiftUI
import AppKit

enum MenuBarLabelRenderer {
    private static let baseFontSize: CGFloat = 10
    private static let smallFontSize: CGFloat = 8
    private static let barHeight: CGFloat = NSStatusBar.system.thickness
    private static let pad: CGFloat = 6
    private static let cellGap: CGFloat = 6

    private static var cachedImage: NSImage?
    private static var lastRenderTime: Date = .distantPast

    private static func coinSymbols(for settings: AppSettings) -> [String: String] {
        var dict: [String: String] = [:]
        for coin in settings.allCoins {
            dict[coin.instId] = coin.symbol
        }
        return dict
    }

    static func invalidateCache() {
        cachedImage = nil
        lastRenderTime = .distantPast
    }

    @MainActor
    static func render(priceStore: PriceStore) -> NSImage? {
        let now = Date()
        if let cached = cachedImage, now.timeIntervalSince(lastRenderTime) < 0.5 {
            return cached
        }
        let image = performRender(priceStore: priceStore)
        cachedImage = image
        lastRenderTime = now
        return image
    }

    @MainActor
    private static func performRender(priceStore: PriceStore) -> NSImage? {
        let settings = priceStore.settings
        let symbols = coinSymbols(for: settings)

        switch settings.displayMode {
        case .single:
            guard let ticker = priceStore.currentTicker else {
                return placeholder()
            }
            return singleLine(ticker: ticker, settings: settings, symbols: symbols)

        case .stack:
            let tickers = priceStore.currentPageTickers
            return stackLayout(tickers: tickers, settings: settings, symbols: symbols)
        }
    }

    private static func placeholder() -> NSImage {
        let font = NSFont.systemFont(ofSize: baseFontSize)
        let string = NSAttributedString(string: "--", attributes: [
            .font: font,
            .foregroundColor: NSColor.white
        ])
        let size = NSSize(width: string.size().width + pad * 2, height: barHeight)
        let image = NSImage(size: size)
        image.lockFocus()
        string.draw(at: NSPoint(x: pad, y: (size.height - font.capHeight) / 2))
        image.unlockFocus()
        return image
    }

    private static func singleLine(ticker: Ticker, settings: AppSettings, symbols: [String: String]) -> NSImage {
        let left = makeLeft(symbol: symbols[ticker.instId] ?? ticker.symbol,
                            price: Format.menuBarPrice(ticker.last),
                            fontSize: baseFontSize)

        let right: NSAttributedString? = settings.showChangePct
            ? makeRight(ticker: ticker, settings: settings, fontSize: baseFontSize - 1)
            : nil

        return drawRow(left: left, right: right)
    }

    private static func stackLayout(tickers: [Ticker], settings: AppSettings, symbols: [String: String]) -> NSImage {
        switch tickers.count {
        case 0: return placeholder()
        case 1: return singleLine(ticker: tickers[0], settings: settings, symbols: symbols)
        case 2: return twoColumnLayout(tickers: tickers, settings: settings, symbols: symbols)
        case 3: return threeLayout(tickers: tickers, settings: settings, symbols: symbols)
        default: return gridLayout(tickers: Array(tickers.prefix(4)), settings: settings, symbols: symbols)
        }
    }

    private static func cellParts(_ ticker: Ticker, settings: AppSettings, symbols: [String: String]) -> (left: NSAttributedString, right: NSAttributedString?) {
        let left = makeLeft(symbol: symbols[ticker.instId] ?? ticker.symbol,
                            price: Format.menuBarPrice(ticker.last),
                            fontSize: smallFontSize)
        let right: NSAttributedString? = settings.showChangePct
            ? makeRight(ticker: ticker, settings: settings, fontSize: smallFontSize - 1)
            : nil
        return (left, right)
    }

    private static func makeLeft(symbol: String, price: String, fontSize: CGFloat) -> NSAttributedString {
        let s = NSMutableAttributedString()
        s.append(attr(string: symbol, size: fontSize, weight: .medium, color: .white))
        s.append(attr(string: " ", size: fontSize / 2, weight: .regular, color: .clear))
        s.append(attr(string: price, size: fontSize, weight: .bold, color: .white))
        return s
    }

    private static func makeRight(ticker: Ticker, settings: AppSettings, fontSize: CGFloat) -> NSAttributedString {
        let period = settings.pricePeriod
        let change = Format.changePct(ticker.changePct(for: period))
        let color = settings.changeColor(isUp: ticker.isUp(for: period), isZero: ticker.isZero(for: period))
        return attr(string: change, size: fontSize, weight: .medium, color: color)
    }

    private static func cellFullWidth(left: NSAttributedString, right: NSAttributedString?) -> CGFloat {
        let lw = left.size().width
        guard let right else { return lw }
        return lw + 4 + right.size().width
    }

    private static func drawCell(left: NSAttributedString, right: NSAttributedString?, at origin: NSPoint, cellWidth: CGFloat, rowHeight: CGFloat) {
        let lh = left.size().height
        let y = origin.y + (rowHeight - lh) / 2
        left.draw(at: NSPoint(x: origin.x, y: y))

        if let right {
            let rh = right.size().height
            let rx = origin.x + cellWidth - right.size().width
            let ry = origin.y + (rowHeight - rh) / 2
            right.draw(at: NSPoint(x: rx, y: ry))
        }
    }

    private static func twoColumnLayout(tickers: [Ticker], settings: AppSettings, symbols: [String: String]) -> NSImage {
        let p0 = cellParts(tickers[0], settings: settings, symbols: symbols)
        let p1 = cellParts(tickers[1], settings: settings, symbols: symbols)

        let cw0 = cellFullWidth(left: p0.left, right: p0.right)
        let cw1 = cellFullWidth(left: p1.left, right: p1.right)
        let rowH = max(p0.left.size().height, p1.left.size().height)

        let totalWidth = cw0 + cellGap + cw1 + pad * 2
        let image = NSImage(size: NSSize(width: totalWidth, height: barHeight))
        image.lockFocus()
        let y = (barHeight - rowH) / 2
        drawCell(left: p0.left, right: p0.right, at: NSPoint(x: pad, y: y), cellWidth: cw0, rowHeight: rowH)
        drawCell(left: p1.left, right: p1.right, at: NSPoint(x: pad + cw0 + cellGap, y: y), cellWidth: cw1, rowHeight: rowH)
        image.unlockFocus()
        return image
    }

    private static func threeLayout(tickers: [Ticker], settings: AppSettings, symbols: [String: String]) -> NSImage {
        let p0 = cellParts(tickers[0], settings: settings, symbols: symbols)
        let p1 = cellParts(tickers[1], settings: settings, symbols: symbols)
        let p2 = cellParts(tickers[2], settings: settings, symbols: symbols)

        let cw0 = cellFullWidth(left: p0.left, right: p0.right)
        let cw1 = cellFullWidth(left: p1.left, right: p1.right)
        let cw2 = cellFullWidth(left: p2.left, right: p2.right)
        let rightColW = max(cw1, cw2)

        let rowH = max(p1.left.size().height, p2.left.size().height)
        let leftH = p0.left.size().height

        let totalWidth = cw0 + cellGap + rightColW + pad * 2
        let image = NSImage(size: NSSize(width: totalWidth, height: barHeight))
        image.lockFocus()

        let leftY = (barHeight - leftH) / 2
        drawCell(left: p0.left, right: p0.right, at: NSPoint(x: pad, y: leftY), cellWidth: cw0, rowHeight: leftH)

        let rightX = pad + cw0 + cellGap
        let trY = (barHeight - 2) / 2 + 1
        let brY = trY - rowH + 1
        drawCell(left: p1.left, right: p1.right, at: NSPoint(x: rightX, y: trY), cellWidth: rightColW, rowHeight: rowH)
        drawCell(left: p2.left, right: p2.right, at: NSPoint(x: rightX, y: brY), cellWidth: rightColW, rowHeight: rowH)

        image.unlockFocus()
        return image
    }

    private static func gridLayout(tickers: [Ticker], settings: AppSettings, symbols: [String: String]) -> NSImage {
        let parts = tickers.map { cellParts($0, settings: settings, symbols: symbols) }
        let widths = parts.map { cellFullWidth(left: $0.left, right: $0.right) }

        let topW = max(widths.count > 0 ? widths[0] : 0, widths.count > 1 ? widths[1] : 0)
        let botW = max(widths.count > 2 ? widths[2] : 0, widths.count > 3 ? widths[3] : 0)
        let colW = max(topW, botW)

        let rowH = parts.map { $0.left.size().height }.max() ?? 0
        let innerGap: CGFloat = 1
        let totalWidth = colW * 2 + cellGap + pad * 2
        let totalHeight = rowH * 2 + innerGap

        let image = NSImage(size: NSSize(width: totalWidth, height: barHeight))
        image.lockFocus()
        let topY = (barHeight - totalHeight) / 2

        if parts.indices.contains(0) {
            drawCell(left: parts[0].left, right: parts[0].right, at: NSPoint(x: pad, y: topY + rowH + innerGap), cellWidth: colW, rowHeight: rowH)
        }
        if parts.indices.contains(1) {
            drawCell(left: parts[1].left, right: parts[1].right, at: NSPoint(x: pad + colW + cellGap, y: topY + rowH + innerGap), cellWidth: colW, rowHeight: rowH)
        }
        if parts.indices.contains(2) {
            drawCell(left: parts[2].left, right: parts[2].right, at: NSPoint(x: pad, y: topY), cellWidth: colW, rowHeight: rowH)
        }
        if parts.indices.contains(3) {
            drawCell(left: parts[3].left, right: parts[3].right, at: NSPoint(x: pad + colW + cellGap, y: topY), cellWidth: colW, rowHeight: rowH)
        }

        image.unlockFocus()
        return image
    }

    private static func drawRow(left: NSAttributedString, right: NSAttributedString?) -> NSImage {
        let lh = left.size().height
        let lw = left.size().width

        var totalWidth = lw + pad * 2
        var rw: CGFloat = 0
        if let right {
            rw = right.size().width
            totalWidth = max(totalWidth, lw + 4 + rw + pad * 2)
        }

        let image = NSImage(size: NSSize(width: totalWidth, height: barHeight))
        image.lockFocus()

        let ly = (barHeight - lh) / 2
        left.draw(at: NSPoint(x: pad, y: ly))

        if let right {
            let rh = right.size().height
            let rx = totalWidth - pad - rw
            let ry = (barHeight - rh) / 2
            right.draw(at: NSPoint(x: rx, y: ry))
        }

        image.unlockFocus()
        return image
    }

    private static func attr(
        string: String,
        size: CGFloat,
        weight: NSFont.Weight = .regular,
        color: NSColor? = nil
    ) -> NSAttributedString {
        let font = NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
        var attrs: [NSAttributedString.Key: Any] = [.font: font]
        if let color {
            attrs[.foregroundColor] = color
        }
        return NSAttributedString(string: string, attributes: attrs)
    }
}
