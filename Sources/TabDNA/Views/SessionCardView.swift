import SwiftUI

public struct SessionCardView: View {
    public let session: BrowsingSession
    public var nodes: [BrowsingNode]? = nil
    public let onOpen: () -> Void
    @State private var isHovered = false
    public var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: session.category.icon).foregroundStyle(session.category.color)
                        .frame(width: 30, height: 30)
                        .background(
                            session.category.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
                    Text(session.category.displayName).font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if session.isActive {
                        Text("Current").font(.system(size: 10, weight: .medium))
                            .foregroundStyle(DNAStyle.accent)
                    }
                    Image(systemName: "arrow.up.right").font(.system(size: 11))
                        .foregroundStyle(isHovered ? DNAStyle.accent : Color.secondary)
                }
                Text(session.displayTitle).font(.system(size: 15, weight: .semibold)).lineLimit(2)
                    .frame(height: 38, alignment: .topLeading).frame(maxWidth: .infinity, alignment: .leading)
                Text(
                    session.startTime.formatted(.dateTime.month(.abbreviated).day()) + " · "
                        + session.formattedTimeRange
                )
                .font(.system(size: 11)).foregroundStyle(.secondary)
                MiniGraphPreview(session: session, preloadedNodes: nodes).frame(height: 65)
                    .accessibilityHidden(true)
                HStack {
                    Label("\(session.pageCount) pages", systemImage: "doc.on.doc")
                    Spacer()
                    Text(session.formattedDuration)
                }
                .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading).dnaSurface(padding: 18)
            .overlay(
                RoundedRectangle(cornerRadius: DNAStyle.cardCornerRadius, style: .continuous)
                    .strokeBorder(isHovered ? DNAStyle.accent.opacity(0.4) : Color.clear))
        }
        .buttonStyle(PressableCardStyle()).onHover { isHovered = $0 }
        .accessibilityLabel(
            "Open \(session.displayTitle), \(session.pageCount) pages, \(session.formattedDuration)"
        )
        .help("Explore \(session.displayTitle)")
    }
}
