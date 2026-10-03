import SwiftUI
import AppKit

@MainActor
public final class GraphExporter {
    public static let shared = GraphExporter()

    private init() {}

    /// Exports the browsing tree session as a high-resolution PNG image
    private func pngData(
        session: BrowsingSession,
        nodes: [BrowsingNode],
        layoutMode: GraphLayoutMode = .horizontal,
        positions: [UUID: CGPoint]? = nil
    ) -> Data? {
        var (layouts, edges) = GraphEngine.shared.computeLayout(nodes: nodes, mode: layoutMode)
        if let positions {
            for (id, position) in positions where layouts[id] != nil { layouts[id]?.position = position }
        }
        guard !layouts.isEmpty else { return nil }

        let bounds = GraphViewport.bounds(positions: layouts.values.map { $0.position })
        let exportWidth = max(1000, bounds.width + 80)
        let exportHeight = max(700, bounds.height + 160)
        let origin = CGPoint(x: 40 - bounds.minX, y: 120 - bounds.minY)

        let exportView = ZStack(alignment: .topLeading) {
            Color(nsColor: .windowBackgroundColor)

            // Header watermark
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: session.category.icon)
                        .foregroundStyle(session.category.color)
                    Text(session.displayTitle)
                        .font(.system(size: 20, weight: .bold))
                }
                Text("TabDNA session · \(nodes.count) pages • \(session.branchCount) branches • \(session.formattedDuration)")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.secondary)
            }
            .padding(24)

            // Edges
            Canvas { context, _ in
                for edge in edges {
                    guard let s = layouts[edge.sourceId], let t = layouts[edge.targetId] else { continue }
                    let source = CGPoint(x: s.position.x + origin.x, y: s.position.y + origin.y)
                    let target = CGPoint(x: t.position.x + origin.x, y: t.position.y + origin.y)
                    let path = GraphViewport.edgePath(from: source, to: target, mode: layoutMode)

                    context.stroke(path, with: .color(Color.cyan.opacity(0.6)), lineWidth: 2)
                }
            }

            // Nodes
            ForEach(nodes) { node in
                if let layout = layouts[node.id] {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "globe")
                            Text(node.domain)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.secondary)
                            Spacer()
                            Text(node.formattedDuration)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(Color.secondary)
                        }
                        Text(node.title)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(2)
                    }
                    .padding(10)
                    .frame(width: 220, height: 98)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.12), lineWidth: 1))
                    .position(x: layout.position.x + origin.x, y: layout.position.y + origin.y)
                }
            }
        }
        .frame(width: exportWidth, height: exportHeight)

        let renderer = ImageRenderer(content: exportView)
        renderer.scale = min(2, 8000 / max(exportWidth, exportHeight)) // Bound memory for very long trails.

        guard let cgImage = renderer.cgImage,
              let pngData = NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:]) else {
            return nil
        }

        return pngData
    }

    func savePNG(session: BrowsingSession, nodes: [BrowsingNode], layoutMode: GraphLayoutMode,
                 positions: [UUID: CGPoint]) -> ExportResult {
        SessionExport.save(session: session, fileExtension: "png", type: .png) {
            guard let data = pngData(session: session, nodes: nodes, layoutMode: layoutMode, positions: positions) else {
                throw CocoaError(.fileWriteUnknown)
            }
            return data
        }
    }
}
