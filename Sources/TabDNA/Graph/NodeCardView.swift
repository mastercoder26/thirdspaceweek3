import SwiftUI

public struct NodeCardView: View {
    public let layout: GraphNodeLayout
    public let isSelected: Bool
    public let isSearchMatched: Bool
    public let isBranchHighlighted: Bool
    public var isCurrentlyActiveTab: Bool = false
    public var isReplayFocused: Bool = false
    public let onSelect: () -> Void
    public let onDragDelta: (CGSize) -> Void
    public var onDragEnded: ((CGSize) -> Void)?
    @State private var hovered = false

    public var body: some View {
        let node = layout.node
        let color = isReplayFocused || isBranchHighlighted ? DNAStyle.accent : Color.secondary
        let emphasized = isSelected || isReplayFocused
        ZStack(alignment: .bottomTrailing) {
            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        FaviconView(domain: node.domain, fallbackEmoji: node.faviconEmoji, size: 14)
                        Text(node.domain).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary).lineLimit(1)
                        Spacer(minLength: 3)
                        if node.isPinned {
                            Image(systemName: "star.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(.orange)
                                .help("Starred page")
                        }
                        if isCurrentlyActiveTab {
                            Circle()
                                .fill(.green)
                                .frame(width: 6, height: 6)
                                .help("Active tab")
                        }
                    }
                    Text(node.title).font(.system(size: 12, weight: .semibold)).lineLimit(2)
                        .frame(height: 34, alignment: .topLeading).frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 5) {
                        Text(node.formattedDuration).monospacedDigit().lineLimit(1)
                        Text("·")
                        Text(isReplayFocused ? "Now showing" : node.formattedTime).lineLimit(1)
                        Spacer(minLength: 4)
                        if layout.childIds.count > 1 {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.triangle.branch")
                                    .font(.system(size: 8))
                                Text("\(layout.childIds.count) paths")
                                    .font(.system(size: 8.5, weight: .medium))
                            }
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color.primary.opacity(0.06))
                            .clipShape(Capsule())
                            .help("Later visits share this page as their recorded starting point")
                        }
                    }.font(.system(size: 9)).foregroundStyle(.secondary)
                }.padding(12).frame(width: 220, height: 98)
                    .background(isReplayFocused ? DNAStyle.accent.opacity(0.08) : DNAStyle.surface, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 3, height: 40).padding(.leading, 1)
                    }
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(emphasized || isSearchMatched ? DNAStyle.accent : (hovered ? color.opacity(0.5) : DNAStyle.border), lineWidth: emphasized ? 2 : 1))
                    .shadow(color: .black.opacity(isSelected ? 0.09 : 0.04), radius: 4, y: 2)
            }.buttonStyle(PressableCardStyle())
                .accessibilityLabel("\(node.title), \(node.domain), \(node.formattedDuration)")
                .accessibilityValue(isReplayFocused ? "Current playback page" : "")
                .accessibilityHint("Show page details")
                .help("Select to view details. Drag to reposition.")
                .highPriorityGesture(DragGesture(minimumDistance: 6, coordinateSpace: .named("graphViewport"))
                    .onChanged { onDragDelta($0.translation) }
                    .onEnded { onDragEnded?($0.translation) })
        }.onHover { hovered = $0 }
    }
}
