import SwiftUI

enum GraphViewport {
    static let scaleRange: ClosedRange<CGFloat> = 0.002...2.5
    static func bounds(positions: [CGPoint]) -> CGRect {
        guard let first = positions.first else { return .zero }
        return positions.dropFirst().reduce(CGRect(x: first.x - 110, y: first.y - 49, width: 220, height: 98)) { rect, point in
            rect.union(CGRect(x: point.x - 110, y: point.y - 49, width: 220, height: 98))
        }
    }
    static func fit(bounds: CGRect, viewport: CGSize) -> (scale: CGFloat, offset: CGSize) {
        guard bounds.width > 0, bounds.height > 0, viewport.width > 0, viewport.height > 0 else { return (1, .zero) }
        let scale = min(1, max(scaleRange.lowerBound, min((viewport.width - 80) / bounds.width, (viewport.height - 100) / bounds.height)))
        return (scale, CGSize(width: viewport.width / 2 - bounds.midX * scale, height: viewport.height / 2 - bounds.midY * scale))
    }
    static func zoomOffset(from oldScale: CGFloat, to newScale: CGFloat, offset: CGSize, anchor: CGPoint) -> CGSize {
        let ratio = newScale / oldScale
        return CGSize(width: anchor.x - (anchor.x - offset.width) * ratio,
                      height: anchor.y - (anchor.y - offset.height) * ratio)
    }
    static func edgePath(from source: CGPoint, to target: CGPoint, mode: GraphLayoutMode) -> Path {
        var path = Path()
        switch mode {
        case .horizontal:
            let start = CGPoint(x: source.x + 110, y: source.y)
            let end = CGPoint(x: target.x - 110, y: target.y)
            let dx = max(30, (end.x - start.x) / 2)
            path.move(to: start)
            path.addCurve(to: end, control1: CGPoint(x: start.x + dx, y: start.y), control2: CGPoint(x: end.x - dx, y: end.y))
        case .waterfall:
            let start = CGPoint(x: source.x, y: source.y + 49)
            let end = CGPoint(x: target.x, y: target.y - 49)
            let dy = max(20, (end.y - start.y) / 2)
            path.move(to: start)
            path.addCurve(to: end, control1: CGPoint(x: start.x, y: start.y + dy), control2: CGPoint(x: end.x, y: end.y - dy))
        }
        return path
    }
}
