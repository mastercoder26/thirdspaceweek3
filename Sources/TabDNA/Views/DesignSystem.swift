import SwiftUI
import AppKit

enum DNAStyle {
    static let accent = Color(red: 0.18, green: 0.39, blue: 0.88)
    static let background = Color(nsColor: .windowBackgroundColor)
    static let surface = Color(nsColor: .controlBackgroundColor)
    static let border = Color.primary.opacity(0.08)

    static func branch(_ level: Int) -> Color {
        [accent, Color.purple, Color.teal, Color.orange][abs(level) % 4]
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let seconds = max(0, Int(seconds))
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        return minutes < 60 ? "\(minutes)m" : "\(minutes / 60)h \(minutes % 60)m"
    }
}

struct SurfaceModifier: ViewModifier {
    var padding: CGFloat = 20
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(DNAStyle.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(DNAStyle.border))
    }
}

extension View {
    func dnaSurface(padding: CGFloat = 20) -> some View { modifier(SurfaceModifier(padding: padding)) }
}

struct PressableCardStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(RoundedRectangle(cornerRadius: 16))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.99 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 1), value: configuration.isPressed)
    }
}

struct PageHeading: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 28, weight: .bold)).tracking(-0.6)
            Text(subtitle).font(.system(size: 13)).foregroundStyle(.secondary)
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let detail: String
    let icon: String
    var color: Color = DNAStyle.accent
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                Spacer()
                Image(systemName: icon).foregroundStyle(color)
            }
            Text(value).font(.system(size: 27, weight: .semibold)).tracking(-0.5)
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.75)
            Text(detail).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dnaSurface()
        .accessibilityElement(children: .combine)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 30, weight: .light))
                .foregroundStyle(DNAStyle.accent).padding(18)
                .background(DNAStyle.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
            Text(title).font(.system(size: 18, weight: .semibold))
            Text(message).font(.system(size: 13)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).frame(maxWidth: 340)
        }.padding(32).frame(maxWidth: .infinity)
    }
}

struct TrackingStatusView: View {
    @ObservedObject private var observer = BrowserObserver.shared
    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(observer.isTrackingEnabled ? Color.green : Color.orange).frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 3) {
                Text(observer.isTrackingEnabled ? "Tracking enabled" : "Tracking paused")
                    .font(.system(size: 12, weight: .semibold))
                Text(observer.activeBrowserName).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 0)
            Button { observer.toggleTracking() } label: {
                Image(systemName: observer.isTrackingEnabled ? "pause" : "play.fill")
                    .frame(width: 28, height: 28)
            }.buttonStyle(.borderless)
                .accessibilityLabel(observer.isTrackingEnabled ? "Pause tracking" : "Resume tracking")
                .help(observer.isTrackingEnabled ? "Pause tracking" : "Resume tracking")
        }.padding(14)
    }
}
