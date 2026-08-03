import SwiftUI

/// 24h 趋势图公共几何计算
private enum TrendGeometry {
    /// 将 close 序列映射为折线点（上下留 10% 边距；全等值时画水平中线）
    static func points(from candles: [Candle], size: CGSize) -> [CGPoint]? {
        let closes = candles.map(\.close)
        guard closes.count > 1 else { return nil }

        let minV = closes.min() ?? 0
        let maxV = closes.max() ?? 0
        let range = maxV - minV
        let padY = size.height * 0.1
        let drawHeight = size.height - padY * 2

        return closes.enumerated().map { index, value in
            let x = CGFloat(index) / CGFloat(closes.count - 1) * size.width
            let y: CGFloat
            if range > 0 {
                y = padY + (1 - (value - minV) / range) * drawHeight
            } else {
                y = size.height / 2
            }
            return CGPoint(x: x, y: y)
        }
    }

    static func linePath(from points: [CGPoint]) -> Path {
        var path = Path()
        path.move(to: points[0])
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }
}

/// 行内迷你趋势图
struct SparklineView: View {
    let candles: [Candle]
    let color: Color

    var body: some View {
        Canvas { context, size in
            guard let points = TrendGeometry.points(from: candles, size: size) else { return }
            context.stroke(
                TrendGeometry.linePath(from: points),
                with: .color(color),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
            )
        }
        .frame(width: 58, height: 22)
    }
}

/// 展开详情用的大趋势图（折线 + 渐变填充，悬停显示时间/价格十字指针）
struct TrendChartView: View {
    let candles: [Candle]
    let color: Color

    @State private var hoverLocation: CGPoint?

    var body: some View {
        Canvas { context, size in
            guard let points = TrendGeometry.points(from: candles, size: size) else { return }
            let line = TrendGeometry.linePath(from: points)

            var fill = line
            fill.addLine(to: CGPoint(x: points[points.count - 1].x, y: size.height))
            fill.addLine(to: CGPoint(x: points[0].x, y: size.height))
            fill.closeSubpath()
            context.fill(
                fill,
                with: .linearGradient(
                    Gradient(colors: [color.opacity(0.22), color.opacity(0.02)]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: 0, y: size.height)
                )
            )

            context.stroke(
                line,
                with: .color(color),
                style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)
            )

            if hoverLocation != nil, points.count > 1 {
                drawCrosshair(context: context, size: size, points: points)
            }
        }
        .frame(height: 70)
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                hoverLocation = location
            case .ended:
                hoverLocation = nil
            }
        }
    }

    /// 十字指针：x 吸附到最近的蜡烛，左侧显示价格、底部显示时间
    private func drawCrosshair(context: GraphicsContext, size: CGSize, points: [CGPoint]) {
        guard let hoverLocation else { return }

        let index = Int((hoverLocation.x / size.width * CGFloat(points.count - 1)).rounded())
        let idx = min(max(index, 0), points.count - 1)
        let px = points[idx].x
        let py = points[idx].y

        // 十字虚线
        let dash = StrokeStyle(lineWidth: 1, dash: [3, 3])
        var vLine = Path()
        vLine.move(to: CGPoint(x: px, y: 0))
        vLine.addLine(to: CGPoint(x: px, y: size.height))
        context.stroke(vLine, with: .color(.white.opacity(0.28)), style: dash)
        var hLine = Path()
        hLine.move(to: CGPoint(x: 0, y: py))
        hLine.addLine(to: CGPoint(x: size.width, y: py))
        context.stroke(hLine, with: .color(.white.opacity(0.28)), style: dash)

        // 交点圆点
        let dotRect = CGRect(x: px - 3, y: py - 3, width: 6, height: 6)
        context.fill(Path(ellipseIn: dotRect), with: .color(color))
        context.stroke(Path(ellipseIn: dotRect), with: .color(.white.opacity(0.7)), lineWidth: 1)

        // 左侧价格标签（垂直跟随十字线，边界钳制）
        let priceText = Text(Format.menuBarPrice(candles[idx].close))
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(.white)
        let resolvedPrice = context.resolve(priceText)
        let priceSize = resolvedPrice.measure(
            in: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        )
        let pillW = priceSize.width + 10
        let pillH = priceSize.height + 6
        let pyClamped = min(max(py, pillH / 2 + 3), size.height - pillH / 2 - 3)
        let priceRect = CGRect(x: 3, y: pyClamped - pillH / 2, width: pillW, height: pillH)
        context.fill(Path(roundedRect: priceRect, cornerRadius: 4), with: .color(.black.opacity(0.55)))
        context.draw(resolvedPrice, at: CGPoint(x: priceRect.midX, y: priceRect.midY), anchor: .center)

        // 底部时间标签（水平跟随十字线，边界钳制）
        let timeText = Text(Self.timeText(for: candles[idx].ts))
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(.white)
        let resolvedTime = context.resolve(timeText)
        let timeSize = resolvedTime.measure(
            in: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        )
        let timePillW = timeSize.width + 10
        let timePillH = timeSize.height + 6
        let xClamped = min(max(px, timePillW / 2 + 3), size.width - timePillW / 2 - 3)
        let timeRect = CGRect(x: xClamped - timePillW / 2, y: size.height - timePillH - 3, width: timePillW, height: timePillH)
        context.fill(Path(roundedRect: timeRect, cornerRadius: 4), with: .color(.black.opacity(0.55)))
        context.draw(resolvedTime, at: CGPoint(x: timeRect.midX, y: timeRect.midY), anchor: .center)
    }

    /// K 线时间戳（毫秒）→ HH:mm
    private static func timeText(for ts: TimeInterval) -> String {
        Self.timeFormatter.string(from: Date(timeIntervalSince1970: ts / 1000))
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}
