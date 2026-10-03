import Foundation
import SwiftUI

public enum GraphLayoutMode: String, CaseIterable, Identifiable, Sendable {
    case horizontal = "Connections"
    case waterfall = "Timeline"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .horizontal: return "arrow.right.circle.fill"
        case .waterfall: return "arrow.down.circle.fill"
        }
    }
}

public struct GraphNodeLayout: Identifiable, Sendable {
    public let id: UUID
    public let node: BrowsingNode
    public var position: CGPoint
    public var targetPosition: CGPoint
    public var branchLevel: Int
    public var childIds: [UUID]
    public var isRoot: Bool

    public init(
        node: BrowsingNode,
        position: CGPoint,
        targetPosition: CGPoint,
        branchLevel: Int,
        childIds: [UUID] = [],
        isRoot: Bool = false
    ) {
        self.id = node.id
        self.node = node
        self.position = position
        self.targetPosition = targetPosition
        self.branchLevel = branchLevel
        self.childIds = childIds
        self.isRoot = isRoot
    }
}

public struct GraphEdge: Identifiable, Sendable {
    public var id: String { "\(sourceId.uuidString)->\(targetId.uuidString)" }
    public let sourceId: UUID
    public let targetId: UUID
    public let level: Int
}

public final class GraphEngine: @unchecked Sendable {
    public static let shared = GraphEngine()

    public let nodeWidth: CGFloat = 220
    public let nodeHeight: CGFloat = 98
    public let horizontalSpacing: CGFloat = 160
    public let verticalSpacing: CGFloat = 40

    public init() {}

    /// Computes hierarchical positions for nodes based on selected layout mode
    public func computeLayout(
        nodes: [BrowsingNode],
        mode: GraphLayoutMode = .horizontal
    ) -> (nodes: [UUID: GraphNodeLayout], edges: [GraphEdge]) {
        guard !nodes.isEmpty else { return ([:], []) }

        let nodeMap = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        var childrenMap: [UUID: [UUID]] = [:]
        var rootIds: [UUID] = []

        for node in nodes {
            if let pid = node.parentNodeId, pid != node.id, nodeMap[pid] != nil {
                childrenMap[pid, default: []].append(node.id)
            } else {
                rootIds.append(node.id)
            }
        }

        if rootIds.isEmpty, let first = nodes.sorted(by: { $0.timestampOpened < $1.timestampOpened }).first {
            rootIds.append(first.id)
        }

        // Generate edges
        var edges: [GraphEdge] = []
        for (pid, cids) in childrenMap {
            for cid in cids {
                let level = nodeMap[cid]?.branchLevel ?? 1
                edges.append(GraphEdge(sourceId: pid, targetId: cid, level: level))
            }
        }

        var layoutMap: [UUID: GraphNodeLayout] = [:]

        switch mode {
        case .horizontal:
            layoutMap = computeHorizontalLayout(nodeMap: nodeMap, childrenMap: childrenMap, rootIds: rootIds)
        case .waterfall:
            layoutMap = computeWaterfallLayout(nodeMap: nodeMap, childrenMap: childrenMap, rootIds: rootIds)
        }

        return (layoutMap, edges)
    }

    // MARK: - Horizontal Tree Layout
    private func computeHorizontalLayout(
        nodeMap: [UUID: BrowsingNode],
        childrenMap: [UUID: [UUID]],
        rootIds: [UUID]
    ) -> [UUID: GraphNodeLayout] {
        var layoutMap: [UUID: GraphNodeLayout] = [:]
        var currentY: CGFloat = 120

        func calculateSubtreeHeight(nodeId: UUID, visited: Set<UUID> = []) -> CGFloat {
            if visited.contains(nodeId) { return 0 }
            let children = childrenMap[nodeId] ?? []
            if children.isEmpty {
                return nodeHeight + verticalSpacing
            }
            var height: CGFloat = 0
            var nextVisited = visited
            nextVisited.insert(nodeId)
            for childId in children {
                height += calculateSubtreeHeight(nodeId: childId, visited: nextVisited)
            }
            return max(height, nodeHeight + verticalSpacing)
        }

        func positionSubtree(nodeId: UUID, level: Int, topY: CGFloat, visited: Set<UUID> = []) {
            guard let node = nodeMap[nodeId], !visited.contains(nodeId) else { return }
            var nextVisited = visited
            nextVisited.insert(nodeId)
            let children = childrenMap[nodeId] ?? []
            let subtreeHeight = calculateSubtreeHeight(nodeId: nodeId, visited: visited)

            let posX = 140 + CGFloat(level) * (nodeWidth + horizontalSpacing)
            let posY = topY + (subtreeHeight / 2)

            let layout = GraphNodeLayout(
                node: node,
                position: CGPoint(x: posX, y: posY),
                targetPosition: CGPoint(x: posX, y: posY),
                branchLevel: level,
                childIds: children,
                isRoot: level == 0
            )
            layoutMap[nodeId] = layout

            var childY = topY
            for childId in children {
                let childHeight = calculateSubtreeHeight(nodeId: childId, visited: nextVisited)
                positionSubtree(nodeId: childId, level: level + 1, topY: childY, visited: nextVisited)
                childY += childHeight
            }
        }

        for rootId in rootIds {
            let rootSubtreeHeight = calculateSubtreeHeight(nodeId: rootId)
            positionSubtree(nodeId: rootId, level: 0, topY: currentY)
            currentY += rootSubtreeHeight + 60
        }

        for (nodeId, node) in nodeMap where layoutMap[nodeId] == nil {
            let posX: CGFloat = 140
            let posY = currentY
            layoutMap[nodeId] = GraphNodeLayout(
                node: node,
                position: CGPoint(x: posX, y: posY),
                targetPosition: CGPoint(x: posX, y: posY),
                branchLevel: node.branchLevel,
                childIds: childrenMap[nodeId] ?? [],
                isRoot: false
            )
            currentY += nodeHeight + verticalSpacing
        }

        return layoutMap
    }

    // MARK: - Waterfall Timeline Layout
    private func computeWaterfallLayout(
        nodeMap: [UUID: BrowsingNode],
        childrenMap: [UUID: [UUID]],
        rootIds: [UUID]
    ) -> [UUID: GraphNodeLayout] {
        var layoutMap: [UUID: GraphNodeLayout] = [:]
        let sortedNodes = nodeMap.values.sorted(by: { $0.timestampOpened < $1.timestampOpened })

        var currentY: CGFloat = 120
        for node in sortedNodes {
            let level = node.branchLevel
            let posX = 160 + CGFloat(level) * (nodeWidth + 60)
            let posY = currentY

            layoutMap[node.id] = GraphNodeLayout(
                node: node,
                position: CGPoint(x: posX, y: posY),
                targetPosition: CGPoint(x: posX, y: posY),
                branchLevel: level,
                childIds: childrenMap[node.id] ?? [],
                isRoot: rootIds.contains(node.id)
            )
            currentY += nodeHeight + 40
        }
        return layoutMap
    }

    /// Finds full ancestry trail back to root
    public func findAncestors(for nodeId: UUID, in nodes: [BrowsingNode]) -> [UUID] {
        let nodeMap = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        var result: [UUID] = []
        var visited: Set<UUID> = []
        var currentId: UUID? = nodeId

        while let cid = currentId, let node = nodeMap[cid], !visited.contains(cid) {
            visited.insert(cid)
            result.insert(cid, at: 0)
            currentId = node.parentNodeId
        }
        return result
    }
}
