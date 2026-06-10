import SwiftUI
import AppKit

enum MenuBarLabelRenderer {
    private static let baseFontSize: CGFloat = 10
    private static let smallFontSize: CGFloat = 8
    private static let barHeight: CGFloat = NSStatusBar.system.thickness
    private static let coinSymbols: [String: String] = {
        var dict: [String: String] = [:]
        for coin in AppSettings.allCoins {
            dict[coin.instId] = coin.symbol
        }
        return dict
    }()

    @MainActor
    static func render(priceStore: PriceStore) -> NSImage? {
        let showChange = priceStore.settings.showChangePct

        switch priceStore.settings.displayMode {
        case .single:
            guard let ticker = priceStore.currentTicker else {
                return placeholder()
            }
            return singleLine(ticker: ticker, showChange: showChange)

        case .stack:
            let tickers = priceStore.currentPageTickers
            return stackLayout(tickers: tickers, showChange: showChange)
        }
    }

    private static func placeholder() -> NSImage {
        let text = "--"
        let font = NSFont.systemFont(ofSize: baseFontSize)
        let string = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: NSColor.secondaryLabelColor
        ])

        let size = NSSize(
            width: string.size().width + 4,
            height: barHeight
        )

        let image = NSImage(size: size)
        image.lockFocus()
        string.draw(at: NSPoint(x: 2, y: (size.height - font.capHeight) / 2))
        image.unlockFocus()
        return image
    }

    private static func singleLine(ticker: Ticker, showChange: Bool) -> NSImage {
        let symbol = coinSymbols[ticker.instId] ?? ticker.symbol
        let price = Format.compactPrice(ticker.last)
        let change = Format.changePct(ticker.changePct)

        let symbolAttr = attr(string: symbol, size: baseFontSize, weight: .medium)
        let priceAttr = attr(string: price, size: baseFontSize, weight: .bold)
        let space = attr(string: " ", size: baseFontSize / 2, weight: .regular, color: .clear)

        let mutable = NSMutableAttributedString()
        mutable.append(symbolAttr)
        mutable.append(space)
        mutable.append(priceAttr)

        if showChange {
            mutable.append(space)
            let changeColor: NSColor = ticker.isZero ? .secondaryLabelColor : (ticker.isUp ? .systemGreen : .systemRed)
            let changeAttr = attr(string: change, size: baseFontSize - 1, weight: .medium, color: changeColor)
            mutable.append(changeAttr)
        }

        return drawToString(string: mutable)
    }

    private static func stackLayout(tickers: [Ticker], showChange: Bool) -> NSImage {
        switch tickers.count {
        case 0:
            return placeholder()
        case 1:
            return singleLine(ticker: tickers[0], showChange: showChange)
        case 2:
            return twoColumnLayout(tickers: tickers, showChange: showChange)
        case 3:
            return threeLayout(tickers: tickers, showChange: showChange)
        default:
            return gridLayout(tickers: Array(tickers.prefix(4)), showChange: showChange)
        }
    }

    private static func twoColumnLayout(tickers: [Ticker], showChange: Bool) -> NSImage {
        let left = cellString(ticker: tickers[0], showChange: showChange)
        let right = cellString(ticker: tickers[1], showChange: showChange)

        let leftSize = left.size()
        let rightSize = right.size()
        let gap: CGFloat = 6
        let totalWidth = leftSize.width + gap + rightSize.width + 6
        let rowHeight = max(leftSize.height, rightSize.height)

        let image = NSImage(size: NSSize(width: totalWidth, height: barHeight))
        image.lockFocus()
        let y = (barHeight - rowHeight) / 2
        left.draw(at: NSPoint(x: 3, y: y))
        right.draw(at: NSPoint(x: 3 + leftSize.width + gap, y: y))
        image.unlockFocus()
        return image
    }

    private static func threeLayout(tickers: [Ticker], showChange: Bool) -> NSImage {
        let left = cellString(ticker: tickers[0], showChange: showChange)
        let topRight = cellString(ticker: tickers[1], showChange: showChange)
        let bottomRight = cellString(ticker: tickers[2], showChange: showChange)

        let leftSize = left.size()
        let topRightSize = topRight.size()
        let bottomRightSize = bottomRight.size()

        let rightW = max(topRightSize.width, bottomRightSize.width)
        let gap: CGFloat = 4
        let totalWidth = leftSize.width + gap + rightW + 6
        let rowHeight = max(topRightSize.height, bottomRightSize.height)

        let image = NSImage(size: NSSize(width: totalWidth, height: barHeight))
        image.lockFocus()
        let leftY = (barHeight - leftSize.height) / 2
        left.draw(at: NSPoint(x: 3, y: leftY))

        let rightX: CGFloat = 3 + leftSize.width + gap
        let trY = (barHeight - 2) / 2 + 1
        let brY = trY - rowHeight + 1
        topRight.draw(at: NSPoint(x: rightX, y: trY))
        bottomRight.draw(at: NSPoint(x: rightX, y: brY))
        image.unlockFocus()
        return image
    }

    private static func gridLayout(tickers: [Ticker], showChange: Bool) -> NSImage {
        let cells = tickers.map { cellString(ticker: $0, showChange: showChange) }

        let top1 = cells.count > 0 ? cells[0].size() : .zero
        let top2 = cells.count > 1 ? cells[1].size() : .zero
        let bot1 = cells.count > 2 ? cells[2].size() : .zero
        let bot2 = cells.count > 3 ? cells[3].size() : .zero

        let topW = max(top1.width, top2.width)
        let botW = max(bot1.width, bot2.width)
        let colW = max(topW, botW)
        let gap: CGFloat = 6
        let totalWidth = colW * 2 + gap + 6
        let rowH = max(top1.height, bot1.height)
        let innerGap: CGFloat = 1
        let totalHeight = rowH * 2 + innerGap

        let image = NSImage(size: NSSize(width: totalWidth, height: barHeight))
        image.lockFocus()
        let y = (barHeight - totalHeight) / 2

        if cells.count > 0 { cells[0].draw(at: NSPoint(x: 3, y: y + rowH + innerGap)) }
        if cells.count > 1 { cells[1].draw(at: NSPoint(x: 3 + colW + gap, y: y + rowH + innerGap)) }
        if cells.count > 2 { cells[2].draw(at: NSPoint(x: 3, y: y)) }
        if cells.count > 3 { cells[3].draw(at: NSPoint(x: 3 + colW + gap, y: y)) }

        image.unlockFocus()
        return image
    }

    private static func cellString(ticker: Ticker, showChange: Bool) -> NSAttributedString {
        let symbol = coinSymbols[ticker.instId] ?? ticker.symbol
        let price = Format.compactPrice(ticker.last)

        let mutable = NSMutableAttributedString()
        mutable.append(attr(string: symbol, size: smallFontSize, weight: .medium))
        mutable.append(attr(string: " ", size: smallFontSize / 2, weight: .regular, color: .clear))
        mutable.append(attr(string: price, size: smallFontSize, weight: .bold))

        if showChange {
            mutable.append(attr(string: " ", size: smallFontSize / 2, weight: .regular, color: .clear))
            let change = Format.changePct(ticker.changePct)
            let changeColor: NSColor = ticker.isZero ? .secondaryLabelColor : (ticker.isUp ? .systemGreen : .systemRed)
            mutable.append(attr(string: change, size: smallFontSize - 1, weight: .medium, color: changeColor))
        }

        return mutable
    }

    private static func drawToString(string: NSAttributedString) -> NSImage {
        let size = string.size()
        let imageWidth = size.width + 6
        let image = NSImage(size: NSSize(width: imageWidth, height: barHeight))
        image.lockFocus()
        string.draw(at: NSPoint(x: 3, y: (barHeight - size.height) / 2))
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
