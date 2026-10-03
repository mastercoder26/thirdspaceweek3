import SwiftUI

public struct NodeCardView: View {
    public let layout: GraphNodeLayout
    public let isSelected: Bool
    public let isHovered: Bool
    public let isSearchMatched: Bool
    public let isBranchHighlighted: Bool
    public var isJustBorn: Bool = false
    public var isCurrentlyActiveTab: Bool = false
    public var isCollapsed: Bool = false
    public let onSelect: () -> Void
    public var onToggleCollapse: (() -> Void)?
    public let onDragDelta: (CGSize) -> Void
    public var onDragEnded: ((CGSize) -> Void)?
    @State private var hovered = false

    public var body: some View {
        let node = layout.node
        let color = DNAStyle.branch(layout.branchLevel)
        ZStack(alignment: .bottomTrailing) {
            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 6) {
                        FaviconView(domain: node.domain, fallbackEmoji: node.faviconEmoji, size: 14)
                        Text(node.domain).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary).lineLimit(1)
                        Spacer(minLength: 3)
                        if node.isPinned { Image(systemName: "star.fill").font(.system(size: 9)).foregroundStyle(.orange) }
                        if isCurrentlyActiveTab { Circle().fill(.green).frame(width: 6, height: 6) }
                    }
                    Text(node.title).font(.system(size: 12, weight: .semibold)).lineLimit(2)
                        .frame(height: 30, alignment: .topLeading).frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 5) {
                        Text(node.formattedDuration).monospacedDigit()
                        Text("·")
                        Text(layout.isRoot ? "Starting page" : "Step \(layout.branchLevel)")
                        Spacer()
                    }.font(.system(size: 9)).foregroundStyle(.secondary)
                }.padding(12).frame(width: 220, height: 98)
                    .background(DNAStyle.surface, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 3, height: 40).padding(.leading, 1)
                    }
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(isSelected || isSearchMatched ? DNAStyle.accent : (hovered ? color.opacity(0.5) : DNAStyle.border), lineWidth: isSelected ? 2 : 1))
                    .shadow(color: .black.opacity(isSelected ? 0.09 : 0.04), radius: 4, y: 2)
            }.buttonStyle(PressableCardStyle())
                .accessibilityLabel("\(node.title), \(node.domain), \(node.formattedDuration)")
                .accessibilityHint("Show page details")
                .help("Select to view details. Drag to reposition.")
                .highPriorityGesture(DragGesture(minimumDistance: 6, coordinateSpace: .named("graphViewport"))
                    .onChanged { onDragDelta($0.translation) }
                    .onEnded { onDragEnded?($0.translation) })
            if !layout.childIds.isEmpty, let toggle = onToggleCollapse {
                Button(action: toggle) {
                    HStack(spacing: 3) {
                        Text("\(layout.childIds.count)")
                        Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    }.font(.system(size: 9, weight: .semibold)).padding(.horizontal, 6).padding(.vertical, 4)
                        .background(isCollapsed ? color.opacity(0.13) : Color.primary.opacity(0.04), in: Capsule())
                }.buttonStyle(.plain).padding(8)
                    .accessibilityLabel(isCollapsed ? "Expand \(layout.childIds.count) branches" : "Collapse \(layout.childIds.count) branches")
                    .help(isCollapsed ? "Expand branches" : "Collapse branches")
            }
        }.onHover { hovered = $0 }
    }
}
