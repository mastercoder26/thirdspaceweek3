import SwiftUI
import AppKit

public struct MainContainerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isCommandPalettePresented = false
    @State private var exportMessage = ""
    @State private var exportFailed = false
    @State private var notificationTask: Task<Void, Never>?

    public var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 21, weight: .medium)).foregroundStyle(DNAStyle.accent)
                        .frame(width: 38, height: 38)
                        .background(DNAStyle.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TabDNA").font(.system(size: 17, weight: .bold)).tracking(-0.3)
                        Text("Browsing history").font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                    Spacer()
                }.padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 20)
                List(NavigationTab.allCases, selection: $appState.selectedTab) { tab in
                    NavigationLink(value: tab) {
                        Label(tab.rawValue, systemImage: tab.icon)
                            .font(.system(size: 13, weight: .medium)).padding(.vertical, 3)
                    }
                }.listStyle(.sidebar)
                VStack(alignment: .leading, spacing: 8) {
                    Button { isCommandPalettePresented = true } label: {
                        HStack {
                            Label("Quick search", systemImage: "magnifyingglass")
                            Spacer()
                            Text("⌘K").foregroundStyle(.secondary)
                        }.font(.system(size: 12)).padding(10)
                    }.buttonStyle(.plain)
                    Divider()
                    TrackingStatusView()
                    Label("History stays on this Mac", systemImage: "lock.shield")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                        .padding(.horizontal, 14).padding(.bottom, 14)
                }.padding(.horizontal, 6)
            }.navigationSplitViewColumnWidth(min: 190, ideal: 215, max: 250)
        } detail: {
            ZStack {
                content.id(appState.selectedTab)
                    .transition(.opacity)
                    .animation(.easeOut(duration: reduceMotion ? 0.1 : 0.18), value: appState.selectedTab)
                if isCommandPalettePresented {
                    CommandPaletteView(isPresented: $isCommandPalettePresented)
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                        .zIndex(10)
                }
            }
            .animation(.easeOut(duration: reduceMotion ? 0.1 : 0.18), value: appState.selectedTab)
            .animation(reduceMotion ? .easeOut(duration: 0.1) : .spring(response: 0.3, dampingFraction: 1), value: isCommandPalettePresented)
            .background(DNAStyle.background)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(appState.selectedTab == .explore ? (appState.selectedSession?.displayTitle ?? "Explore") : appState.selectedTab.rawValue)
                        .font(.system(size: 13, weight: .semibold)).lineLimit(1)
                }
                if appState.selectedTab == .explore, let session = appState.selectedSession {
                    ToolbarItem {
                        Menu {
                            ForEach(appState.sessions) { item in
                                Button(item.displayTitle) { appState.selectSession(item) }
                            }
                        } label: { Label("Switch session", systemImage: "clock.arrow.circlepath") }
                        .help("Switch session").accessibilityLabel("Switch session")
                    }
                    ToolbarItem {
                        Menu {
                            Button("PNG image") { showExport(GraphExporter.shared.savePNG(session: session, nodes: appState.currentGraphNodes, layoutMode: appState.graphLayoutMode, positions: appState.graphPositions)) }
                            Button("Markdown outline") { showExport(MarkdownExporter.shared.saveMarkdown(session: session, nodes: appState.currentGraphNodes)) }
                            Button("Interactive HTML") { showExport(HTMLExporter.shared.saveHTML(session: session, nodes: appState.currentGraphNodes)) }
                        } label: { Label("Export", systemImage: "square.and.arrow.up") }
                        .disabled(appState.currentGraphNodes.isEmpty)
                    }
                }
                ToolbarItem {
                    Button { appState.startNewSession() } label: { Label("New session", systemImage: "plus") }
                        .keyboardShortcut("n", modifiers: .command).help("New session (⌘N)")
                }
                ToolbarItem {
                    Button { isCommandPalettePresented.toggle() } label: { Label("Search", systemImage: "magnifyingglass") }
                        .keyboardShortcut("k", modifiers: .command).help("Quick search (⌘K)")
                }
            }
            .overlay(alignment: .bottom) {
                if !exportMessage.isEmpty {
                    Label(exportMessage, systemImage: exportFailed ? "exclamationmark.circle" : "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .padding(14).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .padding(.bottom, 16).accessibilityLabel(exportMessage)
                }
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch appState.selectedTab {
        case .dashboard: DashboardView()
        case .sessions: SessionsListView()
        case .saved: SavedPagesView()
        case .statistics: StatisticsView()
        case .settings: SettingsView()
        case .explore:
            if let session = appState.selectedSession {
                VisualizationView(session: session, allNodes: appState.currentGraphNodes).id(session.id)
            } else {
                VStack(spacing: 8) {
                    EmptyStateView(icon: "point.3.connected.trianglepath.dotted", title: "Choose a session", message: "Open a session from your library to see its pages and connections.")
                    Button("Open session library") { appState.selectedTab = .sessions }.buttonStyle(.borderedProminent)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func showExport(_ result: ExportResult) {
        if case .cancelled = result { return }
        notificationTask?.cancel()
        switch result {
        case .saved(let url):
            exportFailed = false
            exportMessage = "Saved \(url.lastPathComponent)"
        case .failed(let message):
            exportFailed = true
            exportMessage = "Couldn’t export: \(message)"
        case .cancelled: break
        }
        notificationTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            if !Task.isCancelled { exportMessage = "" }
        }
    }
}
