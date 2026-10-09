import Testing
import Foundation
@testable import TabDNA

@Suite("TabDNA Core Engine Tests")
struct TabDNATests {
    private func makeTestStore() -> HistoryStore {
        HistoryStore(fileURL: FileManager.default.temporaryDirectory
            .appendingPathComponent("TabDNA-tests-" + UUID().uuidString)
            .appendingPathComponent("history.json"))
    }


    @Test("BrowsingNode Domain Extraction and Emoji Mapping")
    func testNodeDomainAndEmoji() throws {
        let domain1 = BrowsingNode.extractDomain(from: "https://www.google.com/search?q=cold+war")
        #expect(domain1 == "google.com")

        let emojiGoogle = BrowsingNode.suggestEmoji(for: domain1, title: "Google Search")
        #expect(emojiGoogle == "🔍")

        let domain2 = BrowsingNode.extractDomain(from: "https://en.wikipedia.org/wiki/Apollo_Program")
        #expect(domain2 == "en.wikipedia.org")

        let emojiSpace = BrowsingNode.suggestEmoji(for: domain2, title: "Apollo Program — Wikipedia")
        #expect(emojiSpace == "📖" || emojiSpace == "🚀")
    }

    @Test("PrivacyManager Domain Blacklisting and Sanitization")
    func testPrivacyManager() throws {
        let privacy = PrivacyManager(defaults: UserDefaults(suiteName: "TabDNA-tests-" + UUID().uuidString)!)

        // Default blacklisted domains should be blocked
        #expect(privacy.isDomainBlacklisted("chase.com"))
        #expect(privacy.isDomainBlacklisted("secure.bankofamerica.com"))
        #expect(privacy.isDomainBlacklisted("accounts.google.com"))

        // Normal sites should pass
        #expect(!privacy.isDomainBlacklisted("wikipedia.org"))
        #expect(!privacy.isDomainBlacklisted("github.com"))

        // URL sanitization strips tokens and auth codes
        let rawUrl = "https://example.com/page?token=secret123&auth=abc&tab=research"
        let sanitized = privacy.sanitize(url: rawUrl)
        #expect(!sanitized.contains("token=secret123"))
        #expect(!sanitized.contains("auth=abc"))
        #expect(sanitized.contains("tab=research"))

        // Adding and removing custom blacklist domain
        privacy.addDomain("private-site.internal")
        #expect(privacy.isDomainBlacklisted("private-site.internal"))
        privacy.removeDomain("private-site.internal")
        #expect(!privacy.isDomainBlacklisted("private-site.internal"))
    }

    @Test("GraphEngine Branching Tree Layout Computation")
    func testGraphEngineLayout() throws {
        let engine = GraphEngine()
        let sessionId = UUID()
        let baseDate = Date()

        // Root: Google
        let root = BrowsingNode(
            sessionId: sessionId,
            url: "https://google.com",
            title: "Google",
            domain: "google.com",
            timestampOpened: baseDate,
            parentNodeId: nil,
            branchLevel: 0
        )

        // Child 1: Cold War
        let child1 = BrowsingNode(
            sessionId: sessionId,
            url: "https://en.wikipedia.org/wiki/Cold_War",
            title: "Cold War",
            domain: "wikipedia.org",
            timestampOpened: baseDate.addingTimeInterval(30),
            parentNodeId: root.id,
            branchLevel: 1
        )

        // Branch 1A: Cuban Missile Crisis
        let branch1 = BrowsingNode(
            sessionId: sessionId,
            url: "https://en.wikipedia.org/wiki/Cuban_Missile_Crisis",
            title: "Cuban Missile Crisis",
            domain: "wikipedia.org",
            timestampOpened: baseDate.addingTimeInterval(60),
            parentNodeId: child1.id,
            branchLevel: 2
        )

        // Branch 1B: JFK
        let branch2 = BrowsingNode(
            sessionId: sessionId,
            url: "https://en.wikipedia.org/wiki/JFK",
            title: "JFK",
            domain: "wikipedia.org",
            timestampOpened: baseDate.addingTimeInterval(90),
            parentNodeId: child1.id,
            branchLevel: 2
        )

        // Branch 1B-1: Apollo Program
        let branch3 = BrowsingNode(
            sessionId: sessionId,
            url: "https://nasa.gov/apollo",
            title: "Apollo",
            domain: "nasa.gov",
            timestampOpened: baseDate.addingTimeInterval(120),
            parentNodeId: branch2.id,
            branchLevel: 3
        )

        let nodes = [root, child1, branch1, branch2, branch3]
        let (layouts, edges) = engine.computeLayout(nodes: nodes)

        #expect(layouts.count == 5)
        #expect(edges.count == 4)

        // Verify root node layout
        let rootLayout = try #require(layouts[root.id])
        #expect(rootLayout.isRoot == true)
        #expect(rootLayout.branchLevel == 0)

        // Verify branching
        let child1Layout = try #require(layouts[child1.id])
        #expect(child1Layout.childIds.count == 2)
        #expect(child1Layout.childIds.contains(branch1.id))
        #expect(child1Layout.childIds.contains(branch2.id))

        // Verify edge connections
        let hasRootToChild = edges.contains { $0.sourceId == root.id && $0.targetId == child1.id }
        #expect(hasRootToChild)

        let hasJFKToApollo = edges.contains { $0.sourceId == branch2.id && $0.targetId == branch3.id }
        #expect(hasJFKToApollo)
    }

    @Test("Local categories use actual pages without inventing topics")
    func testSessionClassifier() async throws {
        let classifier = SessionClassifier()
        let sessionId = UUID()

        let coldWarNodes = [
            BrowsingNode(sessionId: sessionId, url: "https://google.com", title: "cold war history - Google Search"),
            BrowsingNode(sessionId: sessionId, url: "https://wikipedia.org/wiki/Cold_War", title: "Cold War — Wikipedia"),
            BrowsingNode(sessionId: sessionId, url: "https://wikipedia.org/wiki/Cuban_Missile_Crisis", title: "Cuban Missile Crisis"),
            BrowsingNode(sessionId: sessionId, url: "https://nasa.gov", title: "The Apollo Program — NASA")
        ]

        let (title, category) = await classifier.analyzeSession(nodes: coldWarNodes)
        #expect(category == .research)
        #expect(title == coldWarNodes[0].title)

        let devNodes = [
            BrowsingNode(sessionId: sessionId, url: "https://github.com", title: "apple/swift: The Swift Programming Language"),
            BrowsingNode(sessionId: sessionId, url: "https://stackoverflow.com", title: "SwiftUI Canvas Bezier curves question")
        ]

        let (devTitle, devCategory) = await classifier.analyzeSession(nodes: devNodes)
        #expect(devCategory == .coding)
        #expect(devTitle == devNodes[0].title)
    }

    @Test("HistoryStore In-Memory & Persistence Operations")
    func testHistoryStore() throws {
        let store = makeTestStore()
        let sessionId = UUID()
        let session = BrowsingSession(
            id: sessionId,
            title: "Test Session",
            startTime: Date(),
            isActive: true
        )

        store.saveSession(session)
        let retrieved = store.getSession(id: sessionId)
        #expect(retrieved != nil)
        #expect(retrieved?.title == "Test Session")

        let node = BrowsingNode(
            sessionId: sessionId,
            url: "https://test.org",
            title: "Test Page",
            activeDurationSeconds: 15
        )
        store.saveNode(node)

        let sessionNodes = store.getNodes(for: sessionId)
        #expect(sessionNodes.count == 1)
        #expect(sessionNodes.first?.title == "Test Page")

        // Update duration
        store.updateNodeDuration(nodeId: node.id, durationDelta: 10, lastActive: Date())
        let updatedNodes = store.getNodes(for: sessionId)
        #expect(updatedNodes.first?.activeDurationSeconds == 25)

        // Clean up test session
        store.deleteSession(id: sessionId)
        #expect(store.getSession(id: sessionId) == nil)
        #expect(store.getNodes(for: sessionId).isEmpty)
    }

    @Test("GraphEngine Layout Modes and Ancestor Lineage Tracing")
    func testLayoutModesAndLineage() throws {
        let engine = GraphEngine()
        let sessionId = UUID()
        let now = Date()

        let root = BrowsingNode(sessionId: sessionId, url: "https://google.com", title: "Google", timestampOpened: now, parentNodeId: nil, branchLevel: 0)
        let child = BrowsingNode(sessionId: sessionId, url: "https://wiki.org/coldwar", title: "Cold War", timestampOpened: now.addingTimeInterval(10), parentNodeId: root.id, branchLevel: 1)
        let jfk = BrowsingNode(sessionId: sessionId, url: "https://wiki.org/jfk", title: "JFK", timestampOpened: now.addingTimeInterval(20), parentNodeId: child.id, branchLevel: 2)
        let apollo = BrowsingNode(sessionId: sessionId, url: "https://nasa.gov", title: "Apollo", timestampOpened: now.addingTimeInterval(30), parentNodeId: jfk.id, branchLevel: 3)

        let nodes = [root, child, jfk, apollo]

        // 1. Ancestor tracing
        let ancestors = engine.findAncestors(for: apollo.id, in: nodes)
        #expect(ancestors == [root.id, child.id, jfk.id, apollo.id])

        // 3. Waterfall Layout
        let (waterfallLayouts, waterfallEdges) = engine.computeLayout(nodes: nodes, mode: .waterfall)
        #expect(waterfallLayouts.count == 4)
        #expect(waterfallEdges.count == 3)
    }

    @Test("BrowsingNode Resilient Schema Decoding Fallbacks")
    func testBrowsingNodeResilientDecoding() throws {
        // Minimal JSON from early versions or partial third-party exports
        let jsonString = """
        {
            "id": "11111111-2222-3333-4444-555555555555",
            "sessionId": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
            "url": "https://en.wikipedia.org/wiki/Cold_War"
        }
        """
        let data = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let node = try decoder.decode(BrowsingNode.self, from: data)
        #expect(node.url == "https://en.wikipedia.org/wiki/Cold_War")
        #expect(node.domain == "en.wikipedia.org")
        #expect(node.isPinned == false)
        #expect(node.tags.isEmpty)
        #expect(node.notes == nil)
        #expect(node.branchLevel == 0)
        #expect(node.orderIndex == 0)
        #expect(node.browserName == "Comet")
        #expect(node.faviconEmoji == "📖")
    }

    @Test("HistoryStore O(1) Single Node Lookup")
    func testHistoryStoreSingleNodeLookup() throws {
        let store = makeTestStore()
        let sessionId = UUID()
        let node = BrowsingNode(
            sessionId: sessionId,
            url: "https://apple.com/swift",
            title: "Swift",
            domain: "apple.com"
        )

        store.saveNode(node)
        let fetched = store.getNode(id: node.id)
        #expect(fetched != nil)
        #expect(fetched?.url == "https://apple.com/swift")
        #expect(fetched?.domain == "apple.com")
    }

    @Test("GraphEngine Cycle and Self-Parenting Protection")
    func testGraphEngineCycleProtection() throws {
        let engine = GraphEngine()
        let sId = UUID()
        let idA = UUID()
        let idB = UUID()
        let idC = UUID()

        // Cyclic pair: A -> B -> A
        let nodeA = BrowsingNode(id: idA, sessionId: sId, url: "https://a.com", title: "A", parentNodeId: idB)
        let nodeB = BrowsingNode(id: idB, sessionId: sId, url: "https://b.com", title: "B", parentNodeId: idA)
        // Self-parenting: C -> C
        let nodeC = BrowsingNode(id: idC, sessionId: sId, url: "https://c.com", title: "C", parentNodeId: idC)

        let nodes = [nodeA, nodeB, nodeC]

        // findAncestors must terminate safely despite cycle
        let ancestorsA = engine.findAncestors(for: idA, in: nodes)
        #expect(!ancestorsA.isEmpty)
        #expect(ancestorsA.count <= 2)

        // computeLayout must not hang or stack overflow
        for mode in GraphLayoutMode.allCases {
            let (layouts, _) = engine.computeLayout(nodes: nodes, mode: mode)
            #expect(layouts.count == 3)
            #expect(layouts[idA] != nil)
            #expect(layouts[idB] != nil)
            #expect(layouts[idC] != nil)
        }
    }

    @Test("MarkdownExporter Cycle and Orphan Retention")
    @MainActor
    func testMarkdownExporterCycleProtection() throws {
        let exporter = MarkdownExporter.shared
        let session = BrowsingSession(title: "Cycle Test")
        let id1 = UUID()
        let id2 = UUID()

        let n1 = BrowsingNode(id: id1, sessionId: session.id, url: "https://one.com", title: "Page [1]", parentNodeId: id2)
        let n2 = BrowsingNode(id: id2, sessionId: session.id, url: "https://two.com", title: "Page [2]", parentNodeId: id1)

        let md = exporter.exportSessionToMarkdown(session: session, nodes: [n1, n2])
        #expect(md.contains("Page \\[1\\]"))
        #expect(md.contains("Page \\[2\\]"))
        #expect(md.contains("https://one.com"))
        #expect(md.contains("https://two.com"))
    }

    @Test("HTMLExporter Valid JSON and HTML Sanitization")
    @MainActor
    func testHTMLExporterValidJSONAndEscaping() throws {
        let exporter = HTMLExporter.shared
        let session = BrowsingSession(title: "Research <script>alert('XSS')</script> & Discovery")
        let specialNode = BrowsingNode(
            sessionId: session.id,
            url: "https://example.com/test?q=hello%20world&id=1",
            title: "Test \"Quotes\" & <Tags> \n NextLine \\ Backslash",
            domain: "example.com"
        )

        let html = exporter.generateStandaloneHTML(session: session, nodes: [specialNode])

        // Ensure script tags in title are escaped in the HTML head
        #expect(!html.contains("<title>TabDNA — Research <script>"))
        #expect(html.contains("&lt;script&gt;alert('XSS')&lt;/script&gt;"))

        // Ensure embedded JSON contains valid encoded strings
        #expect(html.contains("const nodes = ["))
        #expect(html.contains("const edges = ["))
    }

}

@Suite("Usability Regression Tests")
struct UsabilityRegressionTests {
    @Test("Session metadata never overwrites page metrics")
    func sessionMetrics() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("history.json")
        let store = HistoryStore(fileURL: url)
        let session = BrowsingSession(title: "Research")
        store.saveSession(session)
        let root = BrowsingNode(sessionId: session.id, url: "https://a.com", title: "A", activeDurationSeconds: 30)
        let child = BrowsingNode(sessionId: session.id, url: "https://b.com", title: "B", activeDurationSeconds: 40, parentNodeId: root.id, branchLevel: 1)
        let sibling = BrowsingNode(sessionId: session.id, url: "https://b.com/2", title: "B2", activeDurationSeconds: 20, parentNodeId: root.id, branchLevel: 1)
        [root, child, sibling].forEach { store.saveNode($0) }
        store.saveSession(session) // Simulate a stale view model saving a title.
        let result = try #require(store.getSession(id: session.id))
        #expect(result.pageCount == 3)
        #expect(result.branchCount == 1)
        #expect(result.maxDepth == 1)
        #expect(result.totalActiveDuration == 90)
        #expect(result.mainDomains.first?.domain == "b.com")
        store.updateNodeDuration(nodeId: child.id, durationDelta: 5, lastActive: Date())
        #expect(store.getSession(id: session.id)?.totalActiveDuration == 95)
        #expect(store.getSession(id: session.id)?.mainDomains.first?.activeDurationSeconds == 65)
        store.flush()
        let reloaded = HistoryStore(fileURL: url)
        #expect(reloaded.getSession(id: session.id)?.pageCount == 3)
    }

    @Test("Clearing history cannot be reversed by queued saves")
    func clearingHistory() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("history.json")
        let store = HistoryStore(fileURL: url)
        let session = BrowsingSession()
        store.saveSession(session)
        for i in 0..<20 { store.saveNode(BrowsingNode(sessionId: session.id, url: "https://example.com/\(i)", title: "Page")) }
        store.clearAllData()
        store.flush()
        let reloaded = HistoryStore(fileURL: url)
        #expect(reloaded.getAllNodes().isEmpty)
        #expect(reloaded.getSessions().isEmpty)
    }

    @Test("Zoom keeps the canvas point beneath its anchor")
    func anchoredZoom() {
        let offset = CGSize(width: -200, height: 40)
        let anchor = CGPoint(x: 400, y: 300)
        let result = GraphViewport.zoomOffset(from: 0.5, to: 1.25, offset: offset, anchor: anchor)
        #expect(abs((anchor.x - result.width) / 1.25 - (anchor.x - offset.width) / 0.5) < 0.001)
        #expect(abs((anchor.y - result.height) / 1.25 - (anchor.y - offset.height) / 0.5) < 0.001)
    }

    @Test("Fit includes negative coordinates and complete node bounds")
    func fittingGraph() {
        let points = [CGPoint(x: -500, y: -300), CGPoint(x: 400, y: 300)]
        let bounds = GraphViewport.bounds(positions: points)
        let viewport = CGSize(width: 900, height: 600)
        let fit = GraphViewport.fit(bounds: bounds, viewport: viewport)
        #expect(bounds.minX == -610)
        #expect(bounds.minY == -349)
        #expect(bounds.width * fit.scale <= viewport.width - 79)
        #expect(bounds.height * fit.scale <= viewport.height - 99)
        #expect(abs(bounds.midX * fit.scale + fit.offset.width - viewport.width / 2) < 0.001)
    }

    @Test("Trees retain separate starting pages without stacking them")
    func separateRoots() {
        let id = UUID()
        let roots = (0..<3).map { BrowsingNode(sessionId: id, url: "https://example.com/\($0)", title: "Root \($0)") }
        let result = GraphEngine().computeLayout(nodes: roots)
        #expect(result.nodes.count == 3)
        #expect(result.nodes.values.allSatisfy { $0.isRoot })
        #expect(Set(result.nodes.values.map { "\($0.position.x),\($0.position.y)" }).count == 3)
    }

    @Test("Excluded domains accept URLs and reject invalid input")
    func domains() {
        #expect(PrivacyManager.normalizedDomain(" https://www.example.com/path?q=1 ") == "example.com")
        #expect(PrivacyManager.normalizedDomain("mail.example.com") == "mail.example.com")
        #expect(PrivacyManager.normalizedDomain("not a domain") == nil)
        #expect(PrivacyManager.normalizedDomain("example..com") == nil)
        #expect(PrivacyManager.normalizedDomain("https://user:password@example.com") == nil)
    }

    @Test("Export filenames cannot introduce path components")
    func exportFilenames() {
        let filename = ExportFilename.slug("../Research / Notes: <Swift>")
        #expect(!filename.contains("/"))
        #expect(!filename.contains(".."))
        #expect(ExportFilename.slug("") == "Session")
    }

    @Test("HTML exports escape title markup and script terminators")
    @MainActor
    func safeHTML() {
        let session = BrowsingSession(title: "<img src=x onerror=alert(1)>")
        let node = BrowsingNode(sessionId: session.id, url: "https://example.com", title: "</script><script>alert(1)</script>")
        let html = HTMLExporter.shared.generateStandaloneHTML(session: session, nodes: [node])
        #expect(!html.contains("<h1><img"))
        #expect(!html.contains("</script><script>alert(1)"))
        #expect(html.contains("<h1>&lt;img"))
        #expect(html.contains("aria-label=\"Session timeline\""))
    }

    @Test("An intentionally empty exclusion list survives a restart")
    func emptyExclusions() {
        let defaults = UserDefaults(suiteName: "TabDNA-tests-" + UUID().uuidString)!
        let manager = PrivacyManager(defaults: defaults)
        manager.getBlacklist().forEach { manager.removeDomain($0) }
        #expect(PrivacyManager(defaults: defaults).getBlacklist().isEmpty)
    }
}

@Suite("Useful Feature Tests")
struct UsefulFeatureTests {
    private func store() -> HistoryStore {
        HistoryStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("history.json"))
    }

    @Test("Saved pages include stars or meaningful notes, and search notes")
    func savedPages() {
        let id = UUID()
        let star = BrowsingNode(sessionId: id, url: "https://example.com", title: "An article", isPinned: true)
        let note = BrowsingNode(sessionId: id, url: "https://example.com/notes", title: "Another article", notes: "Useful keyboard shortcuts")
        let blank = BrowsingNode(sessionId: id, url: "https://example.com/blank", title: "Blank", notes: "   ")
        #expect(SavedPageFilter.all.includes(star))
        #expect(SavedPageFilter.all.includes(note))
        #expect(!SavedPageFilter.all.includes(blank))
        #expect(!SavedPageFilter.starred.includes(note))
        #expect(!SavedPageFilter.notes.includes(star))
        #expect(note.matches(" KEYBOARD "))
        #expect(note.matches("example.com/notes"))
        #expect(!note.matches("unrelated"))
    }

    @Test("Annotations preserve newer recorded duration and timestamps")
    func annotate() throws {
        let store = store()
        let session = BrowsingSession(); store.saveSession(session)
        let page = BrowsingNode(sessionId: session.id, url: "https://example.com", title: "Article", activeDurationSeconds: 20)
        store.saveNode(page)
        let recent = Date().addingTimeInterval(10)
        store.updateNodeDuration(nodeId: page.id, durationDelta: 5, lastActive: recent)
        store.updateAnnotations(nodeId: page.id, notes: "A useful page", isPinned: true)
        let saved = try #require(store.getNode(id: page.id))
        #expect(saved.activeDurationSeconds == 25)
        #expect(saved.timestampLastActive == recent)
        #expect(saved.isPinned && saved.notes == "A useful page")
        store.updateAnnotations(nodeId: page.id, notes: "  ", isPinned: false)
        #expect(store.getNode(id: page.id)?.notes == nil)
        #expect(store.getNode(id: page.id)?.isPinned == false)
        store.flush()
    }

    @Test("Manual session names take precedence and survive reload")
    func rename() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("history.json")
        let store = HistoryStore(fileURL: url)
        var session = BrowsingSession(title: "Browsing", aiTitle: "Suggested title")
        store.saveSession(session)
        store.renameSession(id: session.id, title: "  Product research  ")
        session = try #require(store.getSession(id: session.id))
        session.aiTitle = "Later suggestion"
        store.saveSession(session)
        store.renameSession(id: session.id, title: "  ")
        #expect(store.getSession(id: session.id)?.displayTitle == "Product research")
        store.flush()
        #expect(HistoryStore(fileURL: url).getSession(id: session.id)?.displayTitle == "Product research")
    }

    @Test("Old session data loads without a custom name")
    func oldSession() throws {
        let session = BrowsingSession(title: "Old session")
        let encoded = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(BrowsingSession.self, from: encoded)
        #expect(decoded.customTitle == nil)
        #expect(decoded.displayTitle == "Old session")
    }

    @Test("Session boundaries close the previous session and preserve its pages")
    @MainActor
    func sessionBoundaries() throws {
        let store = store()
        let manager = SessionManager(historyStore: store, observer: nil)
        let firstId = manager.currentSessionId
        let page = BrowsingNode(sessionId: firstId, url: "https://example.com", title: "Article")
        store.saveNode(page); manager.synchronizeCurrentSession()
        let next = manager.startNewSession(title: "Next task")
        #expect(store.getSession(id: firstId)?.isActive == false)
        #expect(store.getSession(id: firstId)?.endTime != nil)
        #expect(store.getNodes(for: firstId).count == 1)
        #expect(manager.currentSessionId == next.id)
        #expect(manager.currentSessionNodes.isEmpty)
        manager.endCurrentSession()
        #expect(store.getSession(id: next.id)?.isActive == false)
        store.flush()
    }

    @Test("Tab switches reuse visits and browsers cannot collide")
    func visits() throws {
        let id = UUID()
        var resolver = BrowserVisitResolver()
        var nodes: [UUID: BrowsingNode] = [:]
        let chrome = BrowserTabInfo(windowId: "1", tabId: "1", url: "https://example.com", title: "A", browserName: "Chrome")
        let root = BrowsingNode(sessionId: id, url: chrome.url, title: "A")
        nodes[root.id] = root; resolver.record(root, tab: chrome)
        #expect(resolver.resolve(tab: chrome, url: chrome.url, sessionId: id, lookup: { nodes[$0] }).existing?.id == root.id)
        let safari = BrowserTabInfo(windowId: "1", tabId: "1", url: "https://example.com", title: "A", browserName: "Safari")
        let other = resolver.resolve(tab: safari, url: safari.url, sessionId: id, lookup: { nodes[$0] })
        #expect(other.existing == nil)
        #expect(other.parent == nil)
        let navigation = resolver.resolve(tab: chrome, url: "https://example.com/new", sessionId: id, lookup: { nodes[$0] })
        #expect(navigation.existing == nil && navigation.parent?.id == root.id)
        resolver.reset()
        #expect(resolver.resolve(tab: chrome, url: chrome.url, sessionId: UUID(), lookup: { nodes[$0] }).parent == nil)
    }

    @Test("Only web URLs can be reopened")
    func reopen() {
        let id = UUID()
        #expect(BrowsingNode(sessionId: id, url: "https://example.com", title: "Web").reopenURL != nil)
        #expect(BrowsingNode(sessionId: id, url: "javascript:alert(1)", title: "Other").reopenURL == nil)
        #expect(BrowsingNode(sessionId: id, url: "file:///tmp/test", title: "Other").reopenURL == nil)
    }
    @Test("Deleting a session removes its saved pages without touching another session")
    func deletion() {
        let store = store()
        let first = BrowsingSession(), second = BrowsingSession()
        store.saveSession(first); store.saveSession(second)
        let page = BrowsingNode(sessionId: first.id, url: "https://example.com", title: "Saved", notes: "A note", isPinned: true)
        let retained = BrowsingNode(sessionId: second.id, url: "https://example.org", title: "Retained")
        store.saveNode(page); store.saveNode(retained)
        store.deleteSession(id: first.id)
        #expect(store.getSession(id: first.id) == nil)
        #expect(store.getNode(id: page.id) == nil)
        #expect(store.getNodes(for: second.id).map { $0.id } == [retained.id])
        store.flush()
    }

    @Test("Automatic naming keeps real titles and does not label ordinary browsing a rabbit hole")
    func actualTitles() async {
        let classifier = SessionClassifier()
        let id = UUID()
        let nodes = (0..<8).map { BrowsingNode(sessionId: id, url: "https://example.com/\($0)", title: "Article \($0)", timestampOpened: Date(timeIntervalSince1970: Double($0))) }
        let result = await classifier.analyzeSession(nodes: nodes)
        #expect(result.title == "Article 0")
        #expect(result.category == .general)
        let unrelated = BrowsingNode(sessionId: id, url: "https://notgithub.com", title: "A normal article")
        #expect(await classifier.analyzeSession(nodes: [unrelated]).category == .general)
    }

    @Test("Markdown preserves notes and safely represents punctuation and links")
    @MainActor
    func markdownLinks() {
        let session = BrowsingSession()
        let page = BrowsingNode(sessionId: session.id, url: "https://example.com/a_(b)", title: "A [useful] page", notes: "First line\nSecond line", isPinned: true)
        let other = BrowsingNode(sessionId: session.id, url: "javascript:alert(1)", title: "Unsafe link")
        let output = MarkdownExporter.shared.exportSessionToMarkdown(session: session, nodes: [page, other])
        #expect(output.contains("(<https://example.com/a_(b)>)"))
        #expect(output.contains("A \\[useful\\] page"))
        #expect(output.contains("> First line\n  > Second line"))
        #expect(!output.contains("javascript:"))
    }

    @Test("Starting again before recording a page reuses the empty current session")
    @MainActor
    func noEmptySessionClutter() {
        let store = store()
        let manager = SessionManager(historyStore: store)
        let id = manager.currentSessionId
        #expect(manager.startNewSession().id == id)
        #expect(manager.startNewSession().id == id)
        #expect(store.getSessions().count == 1)
        store.flush()
    }

}
