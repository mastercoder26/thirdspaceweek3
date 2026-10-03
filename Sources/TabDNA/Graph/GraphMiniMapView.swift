import SwiftUI

public struct GraphMiniMapView: View {
    public let layouts: [UUID: GraphNodeLayout]
    public let edges: [GraphEdge]
    public let positions: [UUID: CGPoint]
    public let visibleNodeIds: Set<UUID>
    public let selectedNodeId: UUID?
    @Binding public var panOffset: CGSize
    public let zoomScale: CGFloat
    public let canvasViewportSize: CGSize

    public var body: some View {
        let bounds = GraphViewport.bounds(positions: positions.filter { visibleNodeIds.contains($0.key) }.map { $0.value }).insetBy(dx: -80, dy: -80)
        let scale = min(180 / max(1, bounds.width), 110 / max(1, bounds.height))
        let inset = CGPoint(x: (180 - bounds.width * scale) / 2, y: (110 - bounds.height * scale) / 2)
        VStack(alignment: .leading, spacing: 8) {
            Text("Overview").font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
            Canvas { context, _ in
                func mapped(_ point: CGPoint) -> CGPoint {
                    CGPoint(x: (point.x - bounds.minX) * scale + inset.x, y: (point.y - bounds.minY) * scale + inset.y)
                }
                for edge in edges where visibleNodeIds.contains(edge.sourceId) && visibleNodeIds.contains(edge.targetId) {
                    if let from = positions[edge.sourceId], let to = positions[edge.targetId] {
                        var path = Path(); path.move(to: mapped(from)); path.addLine(to: mapped(to))
                        context.stroke(path, with: .color(Color.secondary.opacity(0.3)), lineWidth: 1)
                    }
                }
                for id in visibleNodeIds {
                    guard let point = positions[id] else { continue }
                    let pos = mapped(point)
                    context.fill(Path(roundedRect: CGRect(x: pos.x - 3, y: pos.y - 2, width: 6, height: 4), cornerRadius: 1),
                        with: .color(id == selectedNodeId ? Color.orange : DNAStyle.accent))
                }
                let topLeft = mapped(CGPoint(x: -panOffset.width / zoomScale, y: -panOffset.height / zoomScale))
                let viewport = CGRect(x: topLeft.x, y: topLeft.y, width: canvasViewportSize.width / zoomScale * scale, height: canvasViewportSize.height / zoomScale * scale)
                context.fill(Path(roundedRect: viewport, cornerRadius: 2), with: .color(DNAStyle.accent.opacity(0.06)))
                context.stroke(Path(roundedRect: viewport, cornerRadius: 2), with: .color(DNAStyle.accent.opacity(0.65)), lineWidth: 1)
            }.frame(width: 180, height: 110).clipped()
                .contentShape(Rectangle()).gesture(DragGesture(minimumDistance: 0).onChanged { value in
                    let world = CGPoint(x: (value.location.x - inset.x) / scale + bounds.minX, y: (value.location.y - inset.y) / scale + bounds.minY)
                    panOffset = CGSize(width: canvasViewportSize.width / 2 - world.x * zoomScale, height: canvasViewportSize.height / 2 - world.y * zoomScale)
                })
        }.padding(12).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .accessibilityElement(children: .ignore).accessibilityLabel("Overview map, \(visibleNodeIds.count) pages")
    }
}
