import SwiftUI

/// A minimal connected-trail mark that follows the system's light/dark appearance.
struct TabDNALogoMark: View {
    var body: some View {
        Canvas { context, size in
            let points = [
                CGPoint(x: size.width * 0.22, y: size.height * 0.22),
                CGPoint(x: size.width * 0.76, y: size.height * 0.50),
                CGPoint(x: size.width * 0.22, y: size.height * 0.78)
            ]
            var trail = Path()
            trail.move(to: points[0])
            trail.addLine(to: points[1])
            trail.addLine(to: points[2])
            context.stroke(trail, with: .color(.primary), style: StrokeStyle(lineWidth: size.width * 0.075, lineCap: .round, lineJoin: .round))

            let radius = size.width * 0.11
            for point in points {
                let node = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
                context.fill(Path(ellipseIn: node), with: .color(.primary))
            }
        }
        .accessibilityHidden(true)
    }
}
