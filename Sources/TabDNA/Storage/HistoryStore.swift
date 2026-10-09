import Foundation

public struct StoreData: Codable {
    public var sessions: [BrowsingSession]
    public var nodes: [BrowsingNode]

    public init(sessions: [BrowsingSession] = [], nodes: [BrowsingNode] = []) {
        self.sessions = sessions
        self.nodes = nodes
    }
}

public final class HistoryStore: @unchecked Sendable {
    public static let shared = HistoryStore(fileURL: RuntimeConfiguration.testHistoryURL)

    private let queue = DispatchQueue(label: "com.tabdna.historystore", qos: .utility)
    private let fileURL: URL
    private var cachedSessions: [UUID: BrowsingSession] = [:]
    private var cachedNodes: [UUID: BrowsingNode] = [:]
    private var nodesBySession: [UUID: [UUID]] = [:]
    private let lock = NSLock()
    private var pendingSaveWorkItem: DispatchWorkItem?
    private var isDirty = false
    public var saveDebounceInterval: TimeInterval = 5.0

    public init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
            try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            loadFromDisk()
            return
        }
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let tabDNADir = appSupport.appendingPathComponent("TabDNA", isDirectory: true)
        try? FileManager.default.createDirectory(at: tabDNADir, withIntermediateDirectories: true)
        self.fileURL = tabDNADir.appendingPathComponent("tabdna_history.json")
        loadFromDisk()
    }

    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let store = try decoder.decode(StoreData.self, from: data)

            lock.lock()
            defer { lock.unlock() }
            for s in store.sessions {
                cachedSessions[s.id] = s
            }
            for n in store.nodes {
                cachedNodes[n.id] = n
                nodesBySession[n.sessionId, default: []].append(n.id)
            }
            for id in cachedSessions.keys { recomputeMetrics(for: id) }
        } catch {
            print("[HistoryStore] Failed to load data from disk: \(error)")
        }
    }

    private func performDiskWrite() {
        lock.lock()
        let sessions = Array(cachedSessions.values).sorted(by: { $0.startTime > $1.startTime })
        let nodes = Array(cachedNodes.values).sorted(by: { $0.timestampOpened < $1.timestampOpened })
        isDirty = false
        lock.unlock()

        let store = StoreData(sessions: sessions, nodes: nodes)
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(store)
            try data.write(to: self.fileURL, options: .atomic)
        } catch {
            print("[HistoryStore] Failed to write data: \(error)")
        }
    }

    private func saveToDisk(immediate: Bool = true) {
        lock.lock()
        if immediate {
            pendingSaveWorkItem?.cancel()
            pendingSaveWorkItem = nil
            isDirty = false
            lock.unlock()
            queue.async { [weak self] in
                self?.performDiskWrite()
            }
        } else {
            isDirty = true
            if pendingSaveWorkItem != nil {
                lock.unlock()
                return
            }
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                self.lock.lock()
                let shouldSave = self.isDirty
                self.pendingSaveWorkItem = nil
                self.lock.unlock()
                if shouldSave {
                    self.performDiskWrite()
                }
            }
            pendingSaveWorkItem = workItem
            let interval = saveDebounceInterval
            lock.unlock()
            queue.asyncAfter(deadline: .now() + interval, execute: workItem)
        }
    }

    // MARK: - Sessions

    public func saveSession(_ session: BrowsingSession) {
        lock.lock()
        cachedSessions[session.id] = session
        recomputeMetrics(for: session.id)
        lock.unlock()
        saveToDisk()
    }

    public func renameSession(id: UUID, title: String) {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        lock.lock()
        if var session = cachedSessions[id] {
            session.customTitle = String(clean.prefix(120))
            cachedSessions[id] = session
        }
        lock.unlock()
        saveToDisk()
    }

    public func updateAnnotations(nodeId: UUID, notes: String?, isPinned: Bool) {
        lock.lock()
        if var node = cachedNodes[nodeId] {
            node.notes = notes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true ? nil : notes
            node.isPinned = isPinned
            cachedNodes[nodeId] = node
        }
        lock.unlock()
        saveToDisk()
    }

    public func getSessions() -> [BrowsingSession] {
        lock.lock()
        defer { lock.unlock() }
        return Array(cachedSessions.values).sorted(by: { $0.startTime > $1.startTime })
    }

    public func getSession(id: UUID) -> BrowsingSession? {
        lock.lock()
        defer { lock.unlock() }
        return cachedSessions[id]
    }

    public func deleteSession(id: UUID) {
        lock.lock()
        cachedSessions.removeValue(forKey: id)
        if let nodeIds = nodesBySession[id] {
            for nid in nodeIds {
                cachedNodes.removeValue(forKey: nid)
            }
            nodesBySession.removeValue(forKey: id)
        }
        lock.unlock()
        saveToDisk()
    }

    // MARK: - Nodes

    public func saveNode(_ node: BrowsingNode) {
        lock.lock()
        cachedNodes[node.id] = node
        var list = nodesBySession[node.sessionId] ?? []
        if !list.contains(node.id) {
            list.append(node.id)
            nodesBySession[node.sessionId] = list
        }

        recomputeMetrics(for: node.sessionId)

        lock.unlock()
        saveToDisk()
    }

    public func updateNodeDuration(nodeId: UUID, durationDelta: TimeInterval, lastActive: Date) {
        lock.lock()
        guard var node = cachedNodes[nodeId] else {
            lock.unlock()
            return
        }
        node.activeDurationSeconds += durationDelta
        node.timestampLastActive = lastActive
        cachedNodes[nodeId] = node

        recomputeMetrics(for: node.sessionId)
        lock.unlock()
        saveToDisk(immediate: false)
    }

    public func updateNodeTitle(nodeId: UUID, title: String) {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        lock.lock()
        guard var node = cachedNodes[nodeId] else {
            lock.unlock()
            return
        }

        guard node.title != clean else {
            lock.unlock()
            return
        }

        node.title = clean
        if node.faviconEmoji == "🌐" || node.faviconEmoji.isEmpty {
            node.faviconEmoji = BrowsingNode.suggestEmoji(for: node.domain, title: clean)
        }
        cachedNodes[nodeId] = node
        recomputeMetrics(for: node.sessionId)
        lock.unlock()
        saveToDisk(immediate: true)
    }

    public func getNode(id: UUID) -> BrowsingNode? {
        lock.lock()
        defer { lock.unlock() }
        return cachedNodes[id]
    }

    public func getNodes(for sessionId: UUID) -> [BrowsingNode] {
        lock.lock()
        defer { lock.unlock() }
        guard let ids = nodesBySession[sessionId] else { return [] }
        return ids.compactMap { cachedNodes[$0] }.sorted(by: { $0.timestampOpened < $1.timestampOpened })
    }

    public func getAllNodes() -> [BrowsingNode] {
        lock.lock()
        defer { lock.unlock() }
        return Array(cachedNodes.values)
    }

    // Must be called while holding the lock. Nodes are the source of truth.
    private func recomputeMetrics(for sessionId: UUID) {
        guard var session = cachedSessions[sessionId] else { return }
        let nodes = (nodesBySession[sessionId] ?? []).compactMap { cachedNodes[$0] }
        session.pageCount = nodes.count
        session.totalActiveDuration = nodes.reduce(0) { $0 + $1.activeDurationSeconds }
        session.maxDepth = nodes.map { $0.branchLevel }.max() ?? 0
        let parents = Dictionary(grouping: nodes.compactMap { $0.parentNodeId }, by: { $0 })
        session.branchCount = parents.values.filter { $0.count > 1 }.count
        session.mainDomains = Dictionary(grouping: nodes, by: { $0.domain }).map { domain, visits in
            DomainVisitCount(domain: domain, visitCount: visits.count,
                             activeDurationSeconds: visits.reduce(0) { $0 + $1.activeDurationSeconds })
        }.sorted { $0.visitCount == $1.visitCount ? $0.domain < $1.domain : $0.visitCount > $1.visitCount }
        cachedSessions[sessionId] = session
    }

    public func clearAllData() {
        lock.lock()
        cachedSessions.removeAll()
        cachedNodes.removeAll()
        nodesBySession.removeAll()
        pendingSaveWorkItem?.cancel()
        pendingSaveWorkItem = nil
        isDirty = false
        lock.unlock()
        // Serialize with pending writes so deleted data cannot reappear on disk.
        saveToDisk(immediate: true)
    }

    public func flush() {
        lock.lock()
        let hasPending = pendingSaveWorkItem != nil || isDirty
        pendingSaveWorkItem?.cancel()
        pendingSaveWorkItem = nil
        isDirty = false
        lock.unlock()

        queue.sync { [weak self] in
            guard let self = self else { return }
            if hasPending {
                self.performDiskWrite()
            }
        }
    }

    public func exportJSON() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let exportURL = tempDir.appendingPathComponent("TabDNA_Export_\(Int(Date().timeIntervalSince1970)).json")

        lock.lock()
        let sessions = Array(cachedSessions.values)
        let nodes = Array(cachedNodes.values)
        lock.unlock()

        let store = StoreData(sessions: sessions, nodes: nodes)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(store)
        try data.write(to: exportURL, options: .atomic)
        return exportURL
    }
}
