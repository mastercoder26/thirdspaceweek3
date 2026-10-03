import SwiftUI

public struct VisualizationView: View {
    public let session: BrowsingSession
    public let allNodes: [BrowsingNode]
    @EnvironmentObject var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var observer = BrowserObserver.shared
    @State private var layoutMode: GraphLayoutMode = .horizontal
    @State private var layouts: [UUID: GraphNodeLayout] = [:]
    @State private var edges: [GraphEdge] = []
    @State private var positions: [UUID: CGPoint] = [:]
    @State private var dragOrigins: [UUID: CGPoint] = [:]
    @State private var zoomScale: CGFloat = 1
    @State private var panOffset: CGSize = .zero
    @GestureState private var panTranslation: CGSize = .zero
    @State private var lastMagnification: CGFloat = 1
    @State private var selectedNodeId: UUID?
    @State private var searchQuery = ""
    @State private var replay = SessionReplay()
    @State private var viewportSize: CGSize = .zero
    @State private var showsMap = false

    public init(session: BrowsingSession, allNodes: [BrowsingNode]) {
        self.session = session
        self.allNodes = allNodes
    }
    private var sequence: SessionReplaySequence { SessionReplaySequence(nodes: allNodes) }
    private var visibleNodes: [BrowsingNode] {
        let ids = replay.visiblePageIDs
        return allNodes.filter { ids.contains($0.id) }
    }
    private var matchingNodes: [BrowsingNode] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        return allNodes.filter { $0.matches(query) }
    }
    private var selectedNode: BrowsingNode? { allNodes.first { $0.id == selectedNodeId } }
    private var trail: Set<UUID> {
        guard let id = replay.focusedPageID ?? selectedNodeId else { return [] }
        return Set(GraphEngine.shared.findAncestors(for: id, in: allNodes))
    }

    public var body: some View {
        VStack(spacing: 0) {
            controls
            Divider()
            if allNodes.isEmpty {
                VStack {
                    Spacer()
                    EmptyStateView(icon: "point.3.connected.trianglepath.dotted", title: "Ready for your first page", message: "Browse in Comet, Chrome, Safari, or another supported browser. Come back here to see your pages connect.")
                    Button("Tracking settings") { appState.selectedTab = .settings }.buttonStyle(.bordered)
                    Spacer()
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(spacing: 0) {
                    GeometryReader { geometry in
                        graphCanvas(size: geometry.size)
                            .id(layoutMode).transition(.opacity)
                            .onAppear {
                                viewportSize = geometry.size
                                rebuild(reset: true)
                                replayTime = endTime
                                fitGraph()
                                if zoomScale < 0.35, let first = allNodes.first {
                                    center(on: first.id, scale: 0.85)
                                    showsMap = true
                                }
                                if let requested = appState.requestedNodeId { selectNode(requested) }
                            }
                            .onChange(of: geometry.size) { _, size in
                                panOffset.width += (size.width - viewportSize.width) / 2
                                panOffset.height += (size.height - viewportSize.height) / 2
                                viewportSize = size
                            }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    if let node = selectedNode {
                        Divider()
                        NodeDetailsView(node: node,
                            parentNode: allNodes.first { $0.id == node.parentNodeId },
                            childNodes: allNodes.filter { $0.parentNodeId == node.id },
                            onClose: { selectedNodeId = nil },
                            onSelectNode: { selectNode($0) },
                            onNodeUpdated: { appState.updateNode($0) })
                            .id(node.id)
                            .transition(reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))
                    }
                }
                Divider()
                TimelineReplayView(currentReplayTime: $replayTime, followsLatest: $followsLatest,
                    startTime: startTime, endTime: endTime, totalNodesCount: allNodes.count,
                    visibleNodesCount: allNodes.filter { followsLatest || $0.timestampOpened <= replayTime }.count)
                    .padding(.horizontal, 18).padding(.vertical, 10)
            }
        }.background(DNAStyle.background)
        .animation(reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.32, dampingFraction: 1), value: selectedNodeId)
        .animation(.easeOut(duration: reduceMotion ? 0.1 : 0.18), value: layoutMode)
        .animation(.easeOut(duration: reduceMotion ? 0.1 : 0.18), value: Set(visibleNodes.map { $0.id }))
        .onChange(of: allNodes) { old, new in
            let changedStructure = old.map { $0.id } != new.map { $0.id }
            rebuild(reset: false)
            if followsLatest { replayTime = endTime }
            if changedStructure && old.isEmpty { fitGraph() }
            if let selectedNodeId, !new.contains(where: { $0.id == selectedNodeId }) { self.selectedNodeId = nil }
        }
        .onChange(of: appState.requestedNodeId) { _, id in if let id { selectNode(id) } }
        .onChange(of: replayTime) { _, _ in
            if !followsLatest, let node = selectedNode, node.timestampOpened > replayTime { selectedNodeId = nil }
        }
        .onExitCommand { selectedNodeId = nil; searchQuery = "" }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Picker("Layout", selection: $layoutMode) {
                ForEach(GraphLayoutMode.allCases) { mode in Label(mode.rawValue, systemImage: mode.icon).tag(mode) }
            }.labelsHidden().frame(width: 160)
                .onChange(of: layoutMode) { _, _ in rebuild(reset: true); fitGraph() }
            Divider().frame(height: 20)
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Find a page, site, or note", text: $searchQuery).textFieldStyle(.plain)
                    .onSubmit { if let match = matchingNodes.first { selectNode(match.id) } }
                if !searchQuery.isEmpty {
                    Text("\(matchingNodes.count)").font(.system(size: 11)).foregroundStyle(.secondary)
                    Button { searchQuery = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).accessibilityLabel("Clear graph search")
                }
            }.padding(8).background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8)).frame(maxWidth: 260)
            if !searchQuery.isEmpty {
                Button("Next") { nextMatch() }.disabled(matchingNodes.isEmpty)
            }
            Spacer(minLength: 0)
            Toggle(isOn: $focusBranch) { Image(systemName: "scope") }.toggleStyle(.button)
                .help("Highlight the selected page’s path").accessibilityLabel("Focus selected path")
            Text("\(visibleNodes.count) \(visibleNodes.count == 1 ? "page" : "pages")").font(.system(size: 11)).foregroundStyle(.secondary)
        }.padding(.horizontal, 18).padding(.vertical, 12)
    }

    private func graphCanvas(size: CGSize) -> some View {
        let visible = visibleNodes
        let visibleIds = Set(visible.map { $0.id })
        let matches = Set(matchingNodes.map { $0.id })
        let activeTrail = trail
        let offset = CGSize(width: panOffset.width + panTranslation.width, height: panOffset.height + panTranslation.height)
        return ZStack(alignment: .topLeading) {
            Canvas { context, canvasSize in
                let spacing: CGFloat = 24
                for x in stride(from: CGFloat(0), through: canvasSize.width, by: spacing) {
                    for y in stride(from: CGFloat(0), through: canvasSize.height, by: spacing) {
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.5, height: 1.5)), with: .color(Color.primary.opacity(0.06)))
                    }
                }
            }.background(DNAStyle.surface.opacity(0.35))
                .contentShape(Rectangle())
                .gesture(DragGesture().updating($panTranslation) { value, state, _ in state = value.translation }
                    .onEnded { value in panOffset.width += value.translation.width; panOffset.height += value.translation.height })
                .onTapGesture { selectedNodeId = nil }

            GraphEdgesCanvas(edges: edges, positions: positions, visibleIds: visibleIds,
                trail: activeTrail, focusBranch: focusBranch, mode: layoutMode,
                scale: zoomScale, offset: offset).allowsHitTesting(false)

            ForEach(visible) { node in
                if let layout = layouts[node.id], let point = positions[node.id] {
                    NodeCardView(layout: layout, isSelected: selectedNodeId == node.id,
                        isHovered: false, isSearchMatched: matches.contains(node.id),
                        isBranchHighlighted: activeTrail.contains(node.id),
                        isCurrentlyActiveTab: observer.lastActiveNodeId == node.id && observer.currentTabInfo != nil,
                        isCollapsed: collapsed.contains(node.id),
                        onSelect: { selectedNodeId = selectedNodeId == node.id ? nil : node.id },
                        onToggleCollapse: {
                            withAnimation(.easeOut(duration: reduceMotion ? 0.1 : 0.18)) {
                                if collapsed.contains(node.id) { collapsed.remove(node.id) } else { collapsed.insert(node.id) }
                            }
                        },
                        onDragDelta: { delta in
                            let origin = dragOrigins[node.id] ?? point
                            dragOrigins[node.id] = origin
                            positions[node.id] = CGPoint(x: origin.x + delta.width / zoomScale, y: origin.y + delta.height / zoomScale)
                        },
                        onDragEnded: { _ in dragOrigins[node.id] = nil; appState.graphPositions = positions })
                        .opacity((!searchQuery.isEmpty && !matches.contains(node.id)) || (focusBranch && !activeTrail.isEmpty && !activeTrail.contains(node.id)) ? 0.35 : 1)
                        .transition(.opacity)
                        .scaleEffect(zoomScale)
                        .position(x: point.x * zoomScale + offset.width, y: point.y * zoomScale + offset.height)
                }
            }
        }
        .frame(width: size.width, height: size.height).clipped()
        .coordinateSpace(name: "graphViewport")
        .simultaneousGesture(MagnificationGesture().onChanged { value in
            changeZoom(zoomScale * value / lastMagnification)
            lastMagnification = value
        }.onEnded { _ in lastMagnification = 1 })
        .overlay(alignment: .bottomLeading) {
            HStack(spacing: 4) {
                Button { animateNavigation { changeZoom(zoomScale / 1.25) } } label: { Image(systemName: "minus").frame(width: 25, height: 25) }
                    .help("Zoom out").accessibilityLabel("Zoom out")
                Text("\(Int(zoomScale * 100))%").font(.system(size: 11, weight: .medium)).monospacedDigit().frame(width: 42)
                Button { animateNavigation { changeZoom(zoomScale * 1.25) } } label: { Image(systemName: "plus").frame(width: 25, height: 25) }
                    .help("Zoom in").accessibilityLabel("Zoom in")
                Divider().frame(height: 18)
                Button("Fit") { animateNavigation { fitGraph() } }.help("Fit all visible pages")
                Button("Start") { animateNavigation { if let root = allNodes.first { center(on: root.id, scale: 1) } } }.help("Show the first page at a readable size")
                Button { withAnimation(.easeOut(duration: 0.15)) { showsMap.toggle() } } label: { Image(systemName: "map").frame(width: 25, height: 25) }
                    .help("Show overview map").accessibilityLabel("Toggle overview map")
            }.buttonStyle(.borderless).padding(7)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10)).padding(14)
        }
        .overlay(alignment: .bottomTrailing) {
            if showsMap {
                GraphMiniMapView(layouts: layouts, edges: edges, positions: positions,
                    visibleNodeIds: visibleIds, selectedNodeId: selectedNodeId,
                    panOffset: $panOffset, zoomScale: zoomScale, canvasViewportSize: size).padding(14)
            } else {
                Text("Drag to pan · Pinch to zoom · Select a page for details")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                    .padding(10).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8)).padding(14)
            }
        }
        .overlay(alignment: .topLeading) {
            if !searchQuery.isEmpty && matches.isEmpty {
                Label("No matching pages. Try another title or site.", systemImage: "magnifyingglass")
                    .font(.system(size: 12)).padding(12).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10)).padding(14)
            }
        }
    }

    private func rebuild(reset: Bool) {
        appState.graphLayoutMode = layoutMode
        let structureChanged = Set(layouts.keys) != Set(allNodes.map { $0.id })
        if reset || structureChanged {
            let result = GraphEngine.shared.computeLayout(nodes: allNodes, mode: layoutMode)
            layouts = result.nodes
            edges = result.edges
            positions = Dictionary(uniqueKeysWithValues: result.nodes.map { id, layout in (id, reset ? layout.position : (positions[id] ?? layout.position)) })
            dragOrigins.removeAll()
            appState.graphPositions = positions
        } else {
            for node in allNodes {
                guard let old = layouts[node.id] else { continue }
                layouts[node.id] = GraphNodeLayout(node: node, position: old.position, targetPosition: old.targetPosition,
                    branchLevel: old.branchLevel, childIds: old.childIds, isRoot: old.isRoot)
            }
        }
    }
    private func fitGraph() {
        let bounds = GraphViewport.bounds(positions: visibleNodes.compactMap { positions[$0.id] })
        let fit = GraphViewport.fit(bounds: bounds, viewport: viewportSize)
        zoomScale = fit.scale
        panOffset = fit.offset
    }
    private func changeZoom(_ scale: CGFloat) {
        let next = min(GraphViewport.scaleRange.upperBound, max(GraphViewport.scaleRange.lowerBound, scale))
        panOffset = GraphViewport.zoomOffset(from: zoomScale, to: next, offset: panOffset,
            anchor: CGPoint(x: viewportSize.width / 2, y: viewportSize.height / 2))
        zoomScale = next
    }
    private func center(on id: UUID, scale: CGFloat = 1) {
        guard let point = positions[id] else { return }
        zoomScale = scale
        panOffset = CGSize(width: viewportSize.width / 2 - point.x * scale, height: viewportSize.height / 2 - point.y * scale)
    }
    private func selectNode(_ id: UUID) {
        collapsed.subtract(GraphEngine.shared.findAncestors(for: id, in: allNodes))
        followsLatest = true
        replayTime = endTime
        animateNavigation {
            selectedNodeId = id
            center(on: id)
        }
        appState.requestedNodeId = nil
    }
    private func animateNavigation(_ action: () -> Void) {
        if reduceMotion { action() }
        else { withAnimation(.spring(response: 0.4, dampingFraction: 1), action) }
    }
    private func nextMatch() {
        let matches = matchingNodes
        guard !matches.isEmpty else { return }
        let current = matches.firstIndex { $0.id == selectedNodeId } ?? -1
        selectNode(matches[(current + 1) % matches.count].id)
    }
}

// Animate the edge coordinates with the same presentation values as the page cards.
private struct GraphEdgesCanvas: View, Animatable {
    let edges: [GraphEdge]
    let positions: [UUID: CGPoint]
    let visibleIds: Set<UUID>
    let trail: Set<UUID>
    let focusBranch: Bool
    let mode: GraphLayoutMode
    var scale: CGFloat
    var offset: CGSize
    var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(scale, AnimatablePair(offset.width, offset.height)) }
        set { scale = newValue.first; offset = CGSize(width: newValue.second.first, height: newValue.second.second) }
    }
    var body: some View {
        Canvas { context, _ in
            context.translateBy(x: offset.width, y: offset.height)
            context.scaleBy(x: scale, y: scale)
            for edge in edges where visibleIds.contains(edge.sourceId) && visibleIds.contains(edge.targetId) {
                guard let source = positions[edge.sourceId], let target = positions[edge.targetId] else { continue }
                let highlighted = trail.contains(edge.sourceId) && trail.contains(edge.targetId)
                let dim = focusBranch && !trail.isEmpty && !highlighted
                context.stroke(GraphViewport.edgePath(from: source, to: target, mode: mode),
                    with: .color(DNAStyle.branch(edge.level).opacity(dim ? 0.13 : (highlighted ? 0.85 : 0.4))),
                    style: StrokeStyle(lineWidth: highlighted ? 2.5 : 1.5, lineCap: .round))
            }
        }
    }
}
