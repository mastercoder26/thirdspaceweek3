import SwiftUI

public struct DashboardView: View {
    @EnvironmentObject var appState: AppState

    public var body: some View {
        let allNodes = appState.historyStore.getAllNodes()
        let todayNodes = allNodes.filter { Calendar.current.isDateInToday($0.timestampOpened) }
        let nodesBySession = Dictionary(grouping: allNodes, by: \.sessionId)

        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                PageHeading(
                    title: "Your browsing",
                    subtitle: Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day())
                )

                if let session = appState.sessions.first(where: { $0.pageCount > 0 }) {
                    featuredSession(session, nodes: nodesBySession[session.id])
                } else {
                    welcome
                }

                todaySummary(nodes: todayNodes)
                recentSessions(nodesBySession: nodesBySession)
                librarySummary
            }
            .padding(DNAStyle.pagePadding)
            .frame(maxWidth: DNAStyle.contentWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(DNAStyle.background)
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Start with a few pages")
                .font(.system(size: 23, weight: .semibold))
            Text("Use your browser as usual. Your visits will appear here as connected sessions.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(maxWidth: 500, alignment: .leading)
            Button("Start a session") { appState.startNewSession() }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dnaSurface(padding: 26)
    }

    private func todaySummary(nodes: [BrowsingNode]) -> some View {
        let activeTime = nodes.reduce(0) { $0 + $1.activeDurationSeconds }
        let longestPath = nodes.map(\.branchLevel).max() ?? 0
        let siteCount = Set(nodes.map(\.domain)).count

        return VStack(alignment: .leading, spacing: 12) {
            Text("Today")
                .font(.system(size: 15, weight: .semibold))
            MetricGrid {
                MetricCard(
                    title: "Pages visited", value: "\(nodes.count)", detail: "Recorded today",
                    icon: "doc.on.doc")
                MetricCard(
                    title: "Active browsing", value: DNAStyle.duration(activeTime),
                    detail: "Time on today’s pages", icon: "clock")
                MetricCard(
                    title: "Longest path", value: "\(longestPath)", detail: "Steps from a starting page",
                    icon: "arrow.triangle.branch")
                MetricCard(
                    title: "Sites visited", value: "\(siteCount)", detail: "Different domains today",
                    icon: "globe")
            }
        }
    }

    private func recentSessions(nodesBySession: [UUID: [BrowsingNode]]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Recent sessions")
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
                Button {
                    appState.selectedTab = .sessions
                } label: {
                    Label("View library", systemImage: "arrow.right")
                }
                .buttonStyle(.plain)
                .foregroundStyle(DNAStyle.accent)
            }
            if appState.sessions.isEmpty {
                EmptyStateView(
                    icon: "clock.arrow.circlepath",
                    title: "No sessions yet",
                    message: "Sessions appear here as you browse in a supported browser."
                )
                .dnaSurface()
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 290), spacing: 14)], spacing: 14) {
                    ForEach(appState.sessions.prefix(6)) { session in
                        SessionCardView(session: session, nodes: nodesBySession[session.id]) {
                            appState.selectSession(session)
                        }
                    }
                }
            }
        }
    }

    private var librarySummary: some View {
        HStack {
            Label("Stored on this Mac", systemImage: "lock.shield")
            Spacer()
            Text("\(appState.sessions.count) sessions in your library")
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
    }

    private func featuredSession(_ session: BrowsingSession, nodes: [BrowsingNode]?) -> some View {
        HStack(spacing: 28) {
            VStack(alignment: .leading, spacing: 13) {
                Label(
                    session.isActive ? "Current session" : "Continue browsing",
                    systemImage: session.isActive ? "record.circle" : "clock.arrow.circlepath"
                )
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DNAStyle.accent)
                Text(session.displayTitle)
                    .font(.system(size: 24, weight: .semibold))
                    .tracking(-0.6)
                    .lineLimit(2)
                Text(
                    "\(session.pageCount) pages · \(session.branchCount) \(session.branchCount == 1 ? "branching point" : "branching points") · \(session.formattedDuration)"
                )
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                Button {
                    appState.selectSession(session)
                } label: {
                    Label("Open session", systemImage: "arrow.right")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            MiniGraphPreview(session: session, preloadedNodes: nodes)
                .frame(width: 230, height: 125)
                .accessibilityHidden(true)
        }
        .dnaSurface(padding: 26)
    }
}
