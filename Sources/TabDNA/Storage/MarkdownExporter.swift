import Foundation
import AppKit

@MainActor
public final class MarkdownExporter {
    public static let shared = MarkdownExporter()

    private init() {}

    public func exportSessionToMarkdown(session: BrowsingSession, nodes: [BrowsingNode]) -> String {
        var output = "# TabDNA: \(session.displayTitle)\n\n"
        output += "> **Date:** \(session.formattedTimeRange)  \n"
        output += "> **Total Browsing Time:** \(session.formattedDuration)  \n"
        output += "> **Pages Visited:** \(session.pageCount)  \n"
        output += "> **Branches Formed:** \(session.branchCount)  \n"
        output += "> **Primary Domain:** \(session.topDomain)  \n\n"

        output += "### Browsing tree\n\n"

        let nodeMap = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        var childrenMap: [UUID: [UUID]] = [:]
        var rootIds: [UUID] = []

        var visited: Set<UUID> = []

        for node in nodes {
            if let pid = node.parentNodeId, pid != node.id, nodeMap[pid] != nil {
                childrenMap[pid, default: []].append(node.id)
            } else {
                rootIds.append(node.id)
            }
        }

        if rootIds.isEmpty, let first = nodes.first {
            rootIds.append(first.id)
        }

        func appendNodeTree(nodeId: UUID, indent: Int) {
            guard let node = nodeMap[nodeId], !visited.contains(nodeId) else { return }
            visited.insert(nodeId)
            let indentation = String(repeating: "  ", count: indent)
            let duration = node.formattedDuration
            let title = node.title.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "[", with: "\\[").replacingOccurrences(of: "]", with: "\\]")
                .replacingOccurrences(of: "\n", with: " ")
            let label: String
            if let url = node.reopenURL {
                let destination = url.absoluteString.replacingOccurrences(of: "<", with: "%3C").replacingOccurrences(of: ">", with: "%3E")
                label = "[\(title)](<\(destination)>)"
            } else { label = title }
            output += "\(indentation)- \(node.isPinned ? "★ " : "")\(label) `[\(duration)]`\n"

            if let note = node.notes, !note.isEmpty {
                output += note.components(separatedBy: .newlines).map { "\(indentation)  > \($0)\n" }.joined()
            }

            let children = childrenMap[nodeId] ?? []
            for childId in children {
                appendNodeTree(nodeId: childId, indent: indent + 1)
            }
        }

        for rootId in rootIds {
            appendNodeTree(nodeId: rootId, indent: 0)
        }

        for node in nodes where !visited.contains(node.id) {
            appendNodeTree(nodeId: node.id, indent: 0)
        }

        return output
    }

    func saveMarkdown(session: BrowsingSession, nodes: [BrowsingNode]) -> ExportResult {
        SessionExport.save(session: session, fileExtension: "md", type: .plainText) {
            Data(exportSessionToMarkdown(session: session, nodes: nodes).utf8)
        }
    }
}
