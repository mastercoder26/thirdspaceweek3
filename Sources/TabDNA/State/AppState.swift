import Foundation
import SwiftUI
import Combine

public enum NavigationTab: String, CaseIterable, Identifiable {
    case dashboard = "Overview"
    case sessions = "Session library"
    case saved = "Saved pages"
    case explore = "Session map"
    case statistics = "Insights"
    case settings = "Settings"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2.fill"
        case .sessions: return "list.bullet.indent"
        case .saved: return "star"
        case .explore: return "point.forward.to.point.capsulepath.fill"
        case .statistics: return "chart.bar.xaxis"
        case .settings: return "gearshape.fill"
        }
    }
}

@MainActor
public final class AppState: ObservableObject {
    public static let shared = AppState()

    @Published public var selectedTab: NavigationTab = .dashboard
    @Published public var selectedSessionId: UUID? = nil
    @Published public var sessions: [BrowsingSession] = []
    @Published public var currentGraphNodes: [BrowsingNode] = []
    @Published public var graphLayoutMode: GraphLayoutMode = .horizontal
    @Published public var graphPositions: [UUID: CGPoint] = [:]
    @Published public var requestedNodeId: UUID?
    @Published public var dataRevision = 0


    public let observer = BrowserObserver.shared
    public let sessionManager = SessionManager.shared
    public let historyStore = HistoryStore.shared
    public let privacyManager = PrivacyManager.shared

    private var cancellables = Set<AnyCancellable>()

    private init() {
        refreshData()

        if let first = sessions.first {
            self.selectedSessionId = first.id
            self.currentGraphNodes = historyStore.getNodes(for: first.id)
        }

        observer.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }.store(in: &cancellables)
        setupSessionManagerSubscriptions()
        if observer.isTrackingEnabled { observer.startTracking() }
    }

    private func setupSessionManagerSubscriptions() {
        sessionManager.$currentSessionNodes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] nodes in
                guard let self = self else { return }
                if self.selectedSessionId == self.sessionManager.currentSessionId {
                    self.currentGraphNodes = nodes
                }
            }
            .store(in: &cancellables)

        sessionManager.$currentSession
            .receive(on: DispatchQueue.main)
            .sink { [weak self] session in
                guard let self = self else { return }
                self.refreshData()
                guard let session else { return }
                if let idx = self.sessions.firstIndex(where: { $0.id == session.id }) {
                    self.sessions[idx] = session
                } else if !self.sessions.contains(where: { $0.id == session.id }) {
                    self.sessions.insert(session, at: 0)
                }
            }
            .store(in: &cancellables)
    }

    public func updateNode(_ node: BrowsingNode) {
        // Only annotations are editable here; preserve newer tracking timestamps and duration.
        historyStore.updateAnnotations(nodeId: node.id, notes: node.notes, isPinned: node.isPinned)
        sessionManager.synchronizeCurrentSession()
        dataRevision += 1
        refreshData()
    }

    public func openPage(_ node: BrowsingNode) {
        guard let session = sessions.first(where: { $0.id == node.sessionId }) else { return }
        selectSession(session)
        requestedNodeId = node.id
    }

    public func renameSession(_ session: BrowsingSession, to title: String) {
        historyStore.renameSession(id: session.id, title: title)
        sessionManager.synchronizeCurrentSession()
        refreshData()
    }

    public func refreshData() {
        self.sessions = historyStore.getSessions()
        dataRevision += 1
        if let currentId = selectedSessionId {
            self.currentGraphNodes = historyStore.getNodes(for: currentId)
        }
    }

    public func selectSession(_ session: BrowsingSession) {
        self.requestedNodeId = nil
        self.selectedSessionId = session.id
        self.currentGraphNodes = historyStore.getNodes(for: session.id)
        self.selectedTab = .explore
    }

    public func deleteSession(_ session: BrowsingSession) {
        if sessionManager.currentSessionId == session.id { observer.resetSessionTrackingState() }
        historyStore.deleteSession(id: session.id)
        sessionManager.synchronizeCurrentSession()
        refreshData()
        if selectedSessionId == session.id {
            selectedSessionId = sessions.first?.id
            if let nextId = selectedSessionId {
                currentGraphNodes = historyStore.getNodes(for: nextId)
            } else {
                currentGraphNodes = []
            }
        }
    }

    public func clearAllHistory() {
        observer.resetSessionTrackingState()
        historyStore.clearAllData()
        sessionManager.synchronizeCurrentSession()
        refreshData()
        selectedSessionId = nil
        currentGraphNodes = []
    }

    public var selectedSession: BrowsingSession? {
        guard let id = selectedSessionId else { return nil }
        return sessions.first(where: { $0.id == id })
    }

    public var menuBarIconName: String {
        return observer.isTrackingEnabled ? "point.filled.topleft.down.curvedto.point.bottomright.up" : "pause.circle"
    }

    public func startNewSession() {
        let session = sessionManager.startNewSession()
        refreshData()
        selectSession(session)
    }

}
