import SwiftUI

public struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    private var nodes: [BrowsingNode] { appState.historyStore.getAllNodes() }
    private var today: [BrowsingNode] { nodes.filter { Calendar.current.isDateInToday($0.timestampOpened) } }
    private var recent: [BrowsingSession] { Array(appState.sessions.prefix(6)) }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack(alignment: .center) {
                    PageHeading(title: "Browsing overview", subtitle: Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    Spacer(minLength: 20)
                }

                if let session = appState.sessions.first(where: { $0.pageCount > 0 }) {
                    featuredSession(session)
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Your browsing history, connected", systemImage: "point.3.connected.trianglepath.dotted")
                            .font(.system(size: 23, weight: .semibold)).foregroundStyle(DNAStyle.accent)
                        Text("Browse in your favorite browser. TabDNA connects the pages you visit into a trail you can return to.")
                            .font(.system(size: 14)).foregroundStyle(.secondary).frame(maxWidth: 500, alignment: .leading)
                        HStack {
                            Button("Start a session") { appState.startNewSession() }.buttonStyle(.borderedProminent)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).dnaSurface(padding: 26)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Today, at a glance").font(.system(size: 15, weight: .semibold))
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                        MetricCard(title: "Pages visited", value: "\(today.count)", detail: "Recorded today", icon: "doc.on.doc")
                        MetricCard(title: "Active browsing", value: DNAStyle.duration(today.reduce(0) { $0 + $1.activeDurationSeconds }), detail: "Time spent on today’s pages", icon: "clock", color: .teal)
                        MetricCard(title: "Longest path", value: "\(today.map { $0.branchLevel }.max() ?? 0)", detail: "Steps from a starting page", icon: "arrow.triangle.branch", color: .purple)
                        MetricCard(title: "Sites explored", value: "\(Set(today.map { $0.domain }).count)", detail: "Different domains today", icon: "globe", color: .orange)
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Recent sessions").font(.system(size: 18, weight: .semibold)).tracking(-0.3)
                        Spacer()
                        Button("View library →") { appState.selectedTab = .sessions }.buttonStyle(.plain).foregroundStyle(DNAStyle.accent)
                    }
                    if recent.isEmpty {
                        EmptyStateView(icon: "clock.arrow.circlepath", title: "Nothing recorded yet", message: "Sessions appear here as you browse in a supported browser.").dnaSurface()
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 290), spacing: 14)], spacing: 14) {
                            ForEach(recent) { session in
                                SessionCardView(session: session) { appState.selectSession(session) }
                            }
                        }
                    }
                }
                HStack {
                    Label("Saved locally. Ready when you return.", systemImage: "lock.shield")
                    Spacer()
                    Text("\(appState.sessions.count) sessions in your library")
                }.font(.system(size: 11)).foregroundStyle(.secondary)
            }.padding(28).frame(maxWidth: 1280, alignment: .leading).frame(maxWidth: .infinity)
        }.background(DNAStyle.background)
    }

    private func featuredSession(_ session: BrowsingSession) -> some View {
        HStack(spacing: 28) {
            VStack(alignment: .leading, spacing: 13) {
                Label(session.isActive ? "CURRENT SESSION" : "PICK UP WHERE YOU LEFT OFF", systemImage: session.isActive ? "record.circle" : "clock.arrow.circlepath")
                    .font(.system(size: 10, weight: .semibold)).tracking(1.1).foregroundStyle(DNAStyle.accent)
                Text(session.displayTitle).font(.system(size: 24, weight: .semibold)).tracking(-0.6).lineLimit(2)
                Text("\(session.pageCount) pages · \(session.branchCount) \(session.branchCount == 1 ? "branching point" : "branching points") · \(session.formattedDuration)")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                Button { appState.selectSession(session) } label: {
                    Label("Open session", systemImage: "arrow.right")
                }.buttonStyle(.borderedProminent).controlSize(.large).padding(.top, 4)
            }.frame(maxWidth: .infinity, alignment: .leading)
            MiniGraphPreview(session: session).frame(width: 230, height: 125)
                .background(DNAStyle.accent.opacity(0.025), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)
        }.padding(26)
            .background(DNAStyle.surface, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(DNAStyle.accent.opacity(0.18)))
    }
}

public struct SessionCardView: View {
    public let session: BrowsingSession
    public let onOpen: () -> Void
    @State private var hovered = false
    public var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: session.category.icon).foregroundStyle(session.category.color)
                        .frame(width: 30, height: 30).background(session.category.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
                    Text(session.category.displayName).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                    Spacer()
                    if session.isActive { Text("Current").font(.system(size: 10, weight: .medium)).foregroundStyle(DNAStyle.accent) }
                    Image(systemName: "arrow.up.right").font(.system(size: 11)).foregroundStyle(hovered ? DNAStyle.accent : Color.secondary)
                }
                Text(session.displayTitle).font(.system(size: 15, weight: .semibold)).lineLimit(2)
                    .frame(height: 38, alignment: .topLeading).frame(maxWidth: .infinity, alignment: .leading)
                Text(session.startTime.formatted(.dateTime.month(.abbreviated).day()) + " · " + session.formattedTimeRange)
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                MiniGraphPreview(session: session).frame(height: 65).accessibilityHidden(true)
                HStack {
                    Label("\(session.pageCount) pages", systemImage: "doc.on.doc")
                    Spacer()
                    Text(session.formattedDuration)
                }.font(.system(size: 11)).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading).dnaSurface(padding: 18)
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(hovered ? DNAStyle.accent.opacity(0.4) : Color.clear))
        }.buttonStyle(PressableCardStyle()).onHover { hovered = $0 }
            .accessibilityLabel("Open \(session.displayTitle), \(session.pageCount) pages, \(session.formattedDuration)")
            .help("Explore \(session.displayTitle)")
    }
}

public struct MiniGraphPreview: View {
    public let session: BrowsingSession

    public var body: some View {
        let nodes = HistoryStore.shared.getNodes(for: session.id)
        Canvas { context, size in
            guard !nodes.isEmpty else {
                let p0 = CGPoint(x: 20, y: size.height / 2)
                let p1 = CGPoint(x: size.width - 20, y: size.height / 2)
                var p = Path()
                p.move(to: p0)
                p.addLine(to: p1)
                context.stroke(p, with: .color(Color.secondary.opacity(0.2)), lineWidth: 1.5)
                return
            }

            let maxLevel = max(1, nodes.map { $0.branchLevel }.max() ?? 1)
            var nodesByLevel: [Int: [BrowsingNode]] = [:]
            for n in nodes {
                nodesByLevel[n.branchLevel, default: []].append(n)
            }

            var positions: [UUID: CGPoint] = [:]
            for (level, levelNodes) in nodesByLevel {
                let x = 24 + (CGFloat(level) / CGFloat(maxLevel)) * (size.width - 48)
                let count = levelNodes.count
                for (idx, n) in levelNodes.enumerated() {
                    let y: CGFloat
                    if count == 1 {
                        y = size.height / 2
                    } else {
                        let step = (size.height - 24) / CGFloat(count - 1)
                        y = 12 + CGFloat(idx) * step
                    }
                    positions[n.id] = CGPoint(x: x, y: y)
                }
            }

            // Draw edges
            for n in nodes {
                if let pid = n.parentNodeId, let pPos = positions[pid], let cPos = positions[n.id] {
                    var path = Path()
                    path.move(to: pPos)
                    let midX = (pPos.x + cPos.x) / 2
                    path.addCurve(to: cPos, control1: CGPoint(x: midX, y: pPos.y), control2: CGPoint(x: midX, y: cPos.y))
                    let color = colorForLevel(n.branchLevel)
                    context.stroke(path, with: .color(color.opacity(0.55)), lineWidth: 1.5)
                }
            }

            // Draw node dots
            for n in nodes {
                if let pos = positions[n.id] {
                    let color = colorForLevel(n.branchLevel)
                    let radius: CGFloat = n.parentNodeId == nil ? 4.5 : 3.5
                    let rect = CGRect(x: pos.x - radius, y: pos.y - radius, width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(color))
                }
            }
        }
        .background(Color.primary.opacity(0.02))
    }

    private func colorForLevel(_ level: Int) -> Color {
        switch level % 4 {
        case 0: return Color.cyan
        case 1: return Color.purple
        case 2: return Color.green
        default: return Color.orange
        }
    }
}
