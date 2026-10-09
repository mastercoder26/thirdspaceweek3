import Foundation
import Combine

@MainActor
public final class SessionManager: ObservableObject {
    public static let shared = SessionManager(historyStore: .shared, observer: .shared)

    @Published public private(set) var currentSessionId: UUID
    @Published public private(set) var currentSession: BrowsingSession?
    @Published public private(set) var currentSessionNodes: [BrowsingNode] = []

    var classifier: SessionClassifierProtocol = SessionClassifier()

    private let historyStore: HistoryStore
    private let observer: BrowserObserver?

    public init(historyStore: HistoryStore, observer: BrowserObserver? = nil) {
        self.historyStore = historyStore
        self.observer = observer
        let existingSessions = historyStore.getSessions()
        if let active = existingSessions.first(where: { $0.isActive }) {
            self.currentSessionId = active.id
            self.currentSession = active
            self.currentSessionNodes = historyStore.getNodes(for: active.id)
        } else {
            let newId = UUID()
            let newSession = BrowsingSession(
                id: newId,
                title: "Live Browsing Session",
                startTime: Date(),
                isActive: true
            )
            self.currentSessionId = newId
            self.currentSession = newSession
            historyStore.saveSession(newSession)
        }

        setupObserverHooks()
    }

    private func setupObserverHooks() {
        guard let observer else { return }

        observer.onNewNodeRecorded = { [weak self] newNode in
            self?.handleNewNode(newNode)
        }

        observer.onNodeDurationUpdated = { [weak self] nodeId, delta in
            self?.handleNodeDurationUpdate(nodeId: nodeId, delta: delta)
        }

        observer.onInactivitySessionBoundary = { [weak self] in
            self?.handleInactivityRollover()
        }

        observer.onNodeTitleUpdated = { [weak self] nodeId, title in
            self?.handleNodeTitleUpdate(nodeId: nodeId, title: title)
        }
    }

    public func startNewSession(title: String? = nil) -> BrowsingSession {
        if var current = currentSession, current.isActive, historyStore.getNodes(for: current.id).isEmpty {
            if let title { current.title = title; historyStore.saveSession(current); currentSession = current }
            return current
        }
        if var active = currentSession, active.isActive {
            active.isActive = false
            active.endTime = Date()
            historyStore.saveSession(active)
        }

        observer?.resetSessionTrackingState()

        let newId = UUID()
        let newSession = BrowsingSession(
            id: newId,
            title: title ?? "Browsing Session",
            startTime: Date(),
            isActive: true
        )
        self.currentSessionId = newId
        self.currentSession = newSession
        self.currentSessionNodes = []

        historyStore.saveSession(newSession)
        return newSession
    }

    public func endCurrentSession() {
        guard var session = currentSession, session.isActive else { return }
        session.isActive = false
        session.endTime = Date()
        self.currentSession = session
        historyStore.saveSession(session)

        Task {
            await categorizeSession(id: session.id)
        }
    }

    private func handleNewNode(_ node: BrowsingNode) {
        guard node.sessionId == currentSessionId else { return }
        if !currentSessionNodes.contains(where: { $0.id == node.id }) {
            currentSessionNodes.append(node)
        }

        self.currentSession = historyStore.getSession(id: currentSessionId)

        if currentSessionNodes.count == 3 || currentSessionNodes.count == 7 {
            Task {
                await categorizeSession(id: node.sessionId)
            }
        }
    }

    public func synchronizeCurrentSession() {
        currentSession = historyStore.getSession(id: currentSessionId)
        currentSessionNodes = historyStore.getNodes(for: currentSessionId)
    }

    private func handleNodeDurationUpdate(nodeId: UUID, delta: TimeInterval) {
        if let index = currentSessionNodes.firstIndex(where: { $0.id == nodeId }),
           let saved = historyStore.getNode(id: nodeId) {
            currentSessionNodes[index] = saved
        }
        currentSession = historyStore.getSession(id: currentSessionId)
    }

    private func handleNodeTitleUpdate(nodeId: UUID, title: String) {
        if let index = currentSessionNodes.firstIndex(where: { $0.id == nodeId }),
           let saved = historyStore.getNode(id: nodeId) {
            currentSessionNodes[index] = saved
        }
        currentSession = historyStore.getSession(id: currentSessionId)
    }

    private func handleInactivityRollover() {
        endCurrentSession()
        _ = startNewSession(title: "New Session")
    }

    public func categorizeSession(id: UUID) async {
        let nodes = historyStore.getNodes(for: id)
        guard !nodes.isEmpty else { return }

        let (title, category) = await classifier.analyzeSession(nodes: nodes)

        if var session = historyStore.getSession(id: id) {
            session.aiTitle = title
            session.category = category
            historyStore.saveSession(session)

            if session.id == self.currentSessionId {
                self.currentSession = session
            }
        }
    }
}
