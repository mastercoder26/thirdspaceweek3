import SwiftUI

public struct MiniGraphPreview: View {
    public let session: BrowsingSession
    public var preloadedNodes: [BrowsingNode]? = nil
    @State private var loadedNodes: [BrowsingNode]? = nil

    private var displayNodes: [BrowsingNode] {
        preloadedNodes ?? loadedNodes ?? []
    }

    public init(session: BrowsingSession, preloadedNodes: [BrowsingNode]? = nil) {
        self.session = session
        self.preloadedNodes = preloadedNodes
    }

    public var body: some View {
        let nodes = displayNodes
        Canvas { context, size in
            guard !nodes.isEmpty else {
                let start = CGPoint(x: 20, y: size.height / 2)
                let end = CGPoint(x: size.width - 20, y: size.height / 2)
                var placeholder = Path()
                placeholder.move(to: start)
                placeholder.addLine(to: end)
                context.stroke(placeholder, with: .color(Color.secondary.opacity(0.2)), lineWidth: 1.5)
                return
            }

            if nodes.count == 1, let node = nodes.first {
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let color = DNAStyle.branch(node.branchLevel)
                let radius: CGFloat = 5
                context.fill(
                    Path(
                        ellipseIn: CGRect(
                            x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
                    ), with: .color(color))
                return
            }

            let deepestLevel = nodes.map { $0.branchLevel }.max() ?? 0
            let nodesByLevel = Dictionary(grouping: nodes, by: \.branchLevel)

            var positions: [UUID: CGPoint] = [:]
            for (level, levelNodes) in nodesByLevel {
                let count = levelNodes.count
                for (index, node) in levelNodes.enumerated() {
                    let x: CGFloat =
                        deepestLevel > 0
                        ? 24 + (CGFloat(level) / CGFloat(deepestLevel)) * (size.width - 48)
                        : 24 + (CGFloat(index) / CGFloat(max(1, count - 1))) * (size.width - 48)
                    let y: CGFloat
                    if count == 1 {
                        y = size.height / 2
                    } else {
                        let step = (size.height - 24) / CGFloat(count - 1)
                        y = 12 + CGFloat(index) * step
                    }
                    positions[node.id] = CGPoint(x: x, y: y)
                }
            }

            // Draw connections first so the page dots stay visible at intersections.
            for node in nodes {
                if let parentID = node.parentNodeId, let parentPosition = positions[parentID],
                    let position = positions[node.id]
                {
                    var path = Path()
                    path.move(to: parentPosition)
                    let midX = (parentPosition.x + position.x) / 2
                    path.addCurve(
                        to: position, control1: CGPoint(x: midX, y: parentPosition.y),
                        control2: CGPoint(x: midX, y: position.y))
                    let color = DNAStyle.branch(node.branchLevel)
                    context.stroke(path, with: .color(color.opacity(0.55)), lineWidth: 1.5)
                }
            }

            for node in nodes {
                if let position = positions[node.id] {
                    let color = DNAStyle.branch(node.branchLevel)
                    let radius: CGFloat = node.parentNodeId == nil ? 4.5 : 3.5
                    let rect = CGRect(
                        x: position.x - radius, y: position.y - radius, width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(color))
                }
            }
        }
        .background(Color.primary.opacity(0.02))
        .task(id: session.id) {
            if preloadedNodes == nil && loadedNodes == nil {
                let fetched =
                    await Task.detached(priority: .userInitiated) {
                        HistoryStore.shared.getNodes(for: session.id)
                    }
                    .value
                loadedNodes = fetched
            }
        }
    }
}
