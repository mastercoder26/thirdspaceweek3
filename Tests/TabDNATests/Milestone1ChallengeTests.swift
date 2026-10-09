import Testing
import Foundation
import SwiftUI
import AppKit
@testable import TabDNA

@Suite("Milestone 1 Empirical Stress Tests (Challenger 2)")
struct Milestone1ChallengeTests {

    // =========================================================================
    // SECTION 1: NodeCardView 220x98pt Layout & Descender Invariants
    // =========================================================================

    @Test("NodeCardView font metrics: 12pt semibold line height and descender span")
    func testNodeCardViewFontMetrics() {
        let font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        let ascender = font.ascender
        let descender = font.descender // Negative value in AppKit
        let leading = font.leading
        let singleLineHeight = ascender - descender + leading
        let twoLineHeight = singleLineHeight * 2

        // System font descender is typically ~ -2.5pt
        #expect(descender < -1.5)
        #expect(singleLineHeight > 14.0)
        #expect(singleLineHeight < 17.0)

        // 2 lines of text require ~30.0-33.0pt
        // With the 34pt frame, twoLineHeight must fit within 34pt
        #expect(twoLineHeight <= 34.0)
    }

    @Test("NodeCardView descender clearance with extreme descenders")
    @MainActor
    func testNodeCardViewDescendersDoNotClip() {
        let session = BrowsingSession()
        let descenderTitle = "Typography: physics, glyphs, pythons, geography, archaeology, cryptography, agility, jump"
        let node = BrowsingNode(
            sessionId: session.id,
            url: "https://typography.org/descenders",
            title: descenderTitle,
            activeDurationSeconds: 125,
            isPinned: true
        )
        let layout = GraphNodeLayout(
            node: node,
            position: .zero,
            targetPosition: .zero,
            branchLevel: 1,
            childIds: [UUID(), UUID()],
            isRoot: false
        )

        let card = NodeCardView(
            layout: layout,
            isSelected: true,
            isSearchMatched: false,
            isBranchHighlighted: true,
            isCurrentlyActiveTab: true,
            isReplayFocused: false,
            onSelect: {},
            onDragDelta: { _ in }
        )

        let hosting = NSHostingView(rootView: card)
        hosting.frame = CGRect(x: 0, y: 0, width: 220, height: 98)
        hosting.layoutSubtreeIfNeeded()

        let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds)
        #expect(bitmap != nil)
        #expect(bitmap?.size == CGSize(width: 220, height: 98))

        // Verify fitting size respects 220x98 bounding frame
        let fitting = hosting.fittingSize
        #expect(fitting.width <= 220.5)
        #expect(fitting.height <= 98.5)
    }

    @Test("NodeCardView footer layout on long durations, long times, and large path counts")
    @MainActor
    func testNodeCardViewFooterLongStringsCollisions() {
        let session = BrowsingSession()

        // Test permutations of footer strings:
        // 1. Extreme duration: 999h 59m (activeDurationSeconds: 3,599,940)
        // 2. Focused replay: "Now showing"
        // 3. Huge number of child paths: 9999 paths
        let extremeNode = BrowsingNode(
            sessionId: session.id,
            url: "https://example.com/very/long/path/to/test/string/overflow/behavior",
            title: "Testing Extreme Footer Permutations",
            activeDurationSeconds: 3_599_940, // 999h 59m
            isPinned: true
        )
        #expect(extremeNode.formattedDuration == "999h 59m")

        let largeChildIds = (0..<9999).map { _ in UUID() }
        let extremeLayout = GraphNodeLayout(
            node: extremeNode,
            position: .zero,
            targetPosition: .zero,
            branchLevel: 2,
            childIds: largeChildIds,
            isRoot: false
        )

        let cardReplayFocused = NodeCardView(
            layout: extremeLayout,
            isSelected: false,
            isSearchMatched: false,
            isBranchHighlighted: false,
            isCurrentlyActiveTab: true,
            isReplayFocused: true, // "Now showing"
            onSelect: {},
            onDragDelta: { _ in }
        )

        let hosting = NSHostingView(rootView: cardReplayFocused)
        hosting.frame = CGRect(x: 0, y: 0, width: 220, height: 98)
        hosting.layoutSubtreeIfNeeded()

        let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds)
        #expect(bitmap != nil)
        #expect(bitmap?.size == CGSize(width: 220, height: 98))

        // Fitting size must remain strictly within bounding frame
        let fitting = hosting.fittingSize
        #expect(fitting.width <= 220.5)
        #expect(fitting.height <= 98.5)
    }

    @Test("NodeCardView footer adversarial narrow layout and badge wrapping")
    @MainActor
    func testNodeCardViewFooterAdversarialConstraint() {
        // Construct the most extreme footer possible:
        // Duration: 100,000 hours -> "100000h 0m"
        // Replay focused: "Now showing"
        // Paths: 1,000,000 paths -> "1000000 paths"
        let session = BrowsingSession()
        let monsterNode = BrowsingNode(
            sessionId: session.id,
            url: "https://extreme.com",
            title: "Testing Monster Footer Strings Under Extreme Pressure",
            activeDurationSeconds: 360_000_000, // 100,000 hours
            isPinned: true
        )
        let monsterChildIds = (0..<1_000_000).map { _ in UUID() }
        let monsterLayout = GraphNodeLayout(
            node: monsterNode,
            position: .zero,
            targetPosition: .zero,
            branchLevel: 3,
            childIds: monsterChildIds,
            isRoot: false
        )

        let monsterCard = NodeCardView(
            layout: monsterLayout,
            isSelected: true,
            isSearchMatched: true,
            isBranchHighlighted: true,
            isCurrentlyActiveTab: true,
            isReplayFocused: true,
            onSelect: {},
            onDragDelta: { _ in }
        )

        let hosting = NSHostingView(rootView: monsterCard)
        hosting.frame = CGRect(x: 0, y: 0, width: 220, height: 98)
        hosting.layoutSubtreeIfNeeded()

        let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds)
        #expect(rep != nil)
        #expect(rep?.size == CGSize(width: 220, height: 98))

        let fitting = hosting.fittingSize
        print("Adversarial monster footer fitting size: \(fitting)")
        // Verify that fitting size height does NOT exceed 98pt
        #expect(fitting.height <= 98.5)
        #expect(fitting.width <= 220.5)
    }

    @Test("NodeCardView vertical budget invariant: header + title + footer + paddings == 98pt")
    func testNodeCardViewVerticalBudget() {
        // Vertical budget breakdown:
        let topPadding: CGFloat = 12
        let bottomPadding: CGFloat = 12
        let vstackSpacing1: CGFloat = 6
        let vstackSpacing2: CGFloat = 6
        let titleFrameHeight: CGFloat = 34
        let headerRowHeight: CGFloat = 14 // Favicon is 14pt
        let footerRowHeight: CGFloat = 14 // Font 9pt + Capsule padding 1.5*2 = 14pt

        let totalComputedHeight = topPadding + bottomPadding + headerRowHeight + vstackSpacing1 + titleFrameHeight + vstackSpacing2 + footerRowHeight
        #expect(totalComputedHeight == 98.0)
    }

    // =========================================================================
    // SECTION 2: FaviconView Empty, Unicode, Emoji, and Offline Behaviors
    // =========================================================================

    @Test("FaviconView fallback behavior on empty and whitespace-only strings")
    @MainActor
    func testFaviconViewEmptyAndWhitespaceStrings() {
        let emptyCases = ["", "   ", "\t", "\n", " \t \n "]

        for fallback in emptyCases {
            let view = FaviconView(domain: "example.com", fallbackEmoji: fallback, size: 20)
            let hosting = NSHostingView(rootView: view)
            hosting.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
            hosting.layoutSubtreeIfNeeded()

            let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds)
            #expect(rep != nil)
            #expect(rep?.size == CGSize(width: 20, height: 20))
        }
    }

    @Test("FaviconView behavior on compound emojis, skin tones, and flags")
    @MainActor
    func testFaviconViewCompoundEmojisAndFlags() {
        let emojiCases = [
            "📖",           // standard single
            "👨‍💻",         // ZWJ composite (technologist)
            "👩‍👩‍👧‍👦",      // multi-ZWJ family
            "👍🏽",         // skin tone modifier
            "🇺🇸",         // 2 regional indicator symbols (US flag)
            "🏳️‍🌈",         // ZWJ flag (rainbow)
            "❤️",          // emoji with presentation selector
            "🏎️"          // sports car
        ]

        for emoji in emojiCases {
            let view = FaviconView(domain: "test.org", fallbackEmoji: emoji, size: 24)
            let hosting = NSHostingView(rootView: view)
            hosting.frame = CGRect(x: 0, y: 0, width: 24, height: 24)
            hosting.layoutSubtreeIfNeeded()

            let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds)
            #expect(rep != nil)
            #expect(rep?.size == CGSize(width: 24, height: 24))
            let fitting = hosting.fittingSize
            #expect(fitting.width <= 25.0)
            #expect(fitting.height <= 25.0)
        }
    }

    @Test("FaviconView behavior on special unicode characters, CJK, RTL, and control codepoints")
    @MainActor
    func testFaviconViewSpecialUnicodeAndRTL() {
        let unicodeCases = [
            "עברית",       // Hebrew RTL
            "العربية",     // Arabic RTL
            "日本語",       // Japanese Kanji/Kana
            "한국어",       // Korean Hangul
            "Ångström",    // Latin with combining ring
            "Çağrı",       // Turkish cedilla & breve
            "⌘⌥⇧⎋",        // Mac keyboard symbols
            "★⚡️✨",        // Misc symbols
            "\u{200B}",    // Zero-width space
            "\u{FEFF}",    // Byte order mark
            String(repeating: "🌟", count: 50) // Long emoji sequence
        ]

        for text in unicodeCases {
            let view = FaviconView(domain: "unicode-test.io", fallbackEmoji: text, size: 18)
            let hosting = NSHostingView(rootView: view)
            hosting.frame = CGRect(x: 0, y: 0, width: 18, height: 18)
            hosting.layoutSubtreeIfNeeded()

            let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds)
            #expect(rep != nil)
            #expect(rep?.size == CGSize(width: 18, height: 18))
            // Must not blow out frame bounds
            let fitting = hosting.fittingSize
            #expect(fitting.width <= 19.0)
            #expect(fitting.height <= 19.0)
        }
    }

    @Test("FaviconLoader offline domain error handling and non-blocking resilience")
    @MainActor
    func testFaviconLoaderOfflineHandling() async {
        let loader = FaviconLoader.shared
        let nonexistentDomain = "offline-unreachable-domain-\(UUID().uuidString).invalid"

        // Ensure initially nil
        let initial = loader.favicon(for: nonexistentDomain)
        #expect(initial == nil)

        // Attempt load (should complete without throwing unhandled error)
        await loader.load(nonexistentDomain)

        // Still nil, no crash
        let after = loader.favicon(for: nonexistentDomain)
        #expect(after == nil)
    }

    // =========================================================================
    // SECTION 3: MiniGraphPreview Stress Testing (0, 1, and 1,000 Nodes)
    // =========================================================================

    @Test("MiniGraphPreview with 0 nodes: renders dashed baseline without division-by-zero")
    @MainActor
    func testMiniGraphPreviewZeroNodes() {
        let session = BrowsingSession(id: UUID(), title: "Empty Session", startTime: Date())
        let preview = MiniGraphPreview(session: session, preloadedNodes: [])

        let hosting = NSHostingView(rootView: preview)
        hosting.frame = CGRect(x: 0, y: 0, width: 230, height: 125)
        hosting.layoutSubtreeIfNeeded()

        let start = ContinuousClock.now
        let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds)
        let elapsed = ContinuousClock.now - start

        #expect(rep != nil)
        #expect(rep?.size == CGSize(width: 230, height: 125))
        // Must render in under 50ms
        #expect(elapsed < .milliseconds(50))
    }

    @Test("MiniGraphPreview with 1 node: renders centered dot at exact geometry")
    @MainActor
    func testMiniGraphPreviewOneNode() {
        let session = BrowsingSession(id: UUID(), title: "Single Node Session", startTime: Date())
        let node = BrowsingNode(
            sessionId: session.id,
            url: "https://apple.com",
            title: "Apple",
            branchLevel: 0
        )
        let preview = MiniGraphPreview(session: session, preloadedNodes: [node])

        let hosting = NSHostingView(rootView: preview)
        hosting.frame = CGRect(x: 0, y: 0, width: 230, height: 125)
        hosting.layoutSubtreeIfNeeded()

        let start = ContinuousClock.now
        let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds)
        let elapsed = ContinuousClock.now - start

        #expect(rep != nil)
        #expect(rep?.size == CGSize(width: 230, height: 125))
        #expect(elapsed < .milliseconds(50))
    }

    @Test("MiniGraphPreview with 1,000 nodes flat topology: memory & render performance")
    @MainActor
    func testMiniGraphPreview1000NodesFlat() {
        let session = BrowsingSession(id: UUID(), title: "1000 Flat Nodes Session", startTime: Date())
        var nodes: [BrowsingNode] = []
        nodes.reserveCapacity(1000)

        for i in 0..<1000 {
            nodes.append(BrowsingNode(
                sessionId: session.id,
                url: "https://example.com/page/\(i)",
                title: "Page \(i)",
                branchLevel: 0,
                orderIndex: i
            ))
        }

        let preview = MiniGraphPreview(session: session, preloadedNodes: nodes)
        let hosting = NSHostingView(rootView: preview)
        hosting.frame = CGRect(x: 0, y: 0, width: 230, height: 125)
        hosting.layoutSubtreeIfNeeded()

        let start = ContinuousClock.now
        let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds)
        let elapsed = ContinuousClock.now - start

        #expect(rep != nil)
        #expect(rep?.size == CGSize(width: 230, height: 125))
        // 1,000 nodes must complete canvas rendering in < 300ms (no hang)
        #expect(elapsed < .milliseconds(300))
    }

    @Test("MiniGraphPreview with 1,000 nodes deep tree topology: memory & render performance")
    @MainActor
    func testMiniGraphPreview1000NodesDeepTree() {
        let session = BrowsingSession(id: UUID(), title: "1000 Deep Tree Session", startTime: Date())
        var nodes: [BrowsingNode] = []
        nodes.reserveCapacity(1000)

        var parentId: UUID? = nil
        for i in 0..<1000 {
            let node = BrowsingNode(
                sessionId: session.id,
                url: "https://example.com/step/\(i)",
                title: "Step \(i)",
                parentNodeId: parentId,
                branchLevel: i % 20, // 20 branch levels
                orderIndex: i
            )
            nodes.append(node)
            parentId = node.id
        }

        let preview = MiniGraphPreview(session: session, preloadedNodes: nodes)
        let hosting = NSHostingView(rootView: preview)
        hosting.frame = CGRect(x: 0, y: 0, width: 230, height: 125)
        hosting.layoutSubtreeIfNeeded()

        let start = ContinuousClock.now
        let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds)
        let elapsed = ContinuousClock.now - start

        #expect(rep != nil)
        #expect(rep?.size == CGSize(width: 230, height: 125))
        // Must complete in < 300ms without memory blowup or render hang
        #expect(elapsed < .milliseconds(300))
    }

    @Test("MiniGraphPreview with 1,000 nodes wide tree (branching star)")
    @MainActor
    func testMiniGraphPreview1000NodesWideStar() {
        let session = BrowsingSession(id: UUID(), title: "1000 Star Session", startTime: Date())
        let root = BrowsingNode(
            sessionId: session.id,
            url: "https://example.com/root",
            title: "Root Hub",
            branchLevel: 0
        )
        var nodes: [BrowsingNode] = [root]
        nodes.reserveCapacity(1000)

        for i in 1..<1000 {
            nodes.append(BrowsingNode(
                sessionId: session.id,
                url: "https://example.com/child/\(i)",
                title: "Child \(i)",
                parentNodeId: root.id,
                branchLevel: 1 + (i % 4),
                orderIndex: i
            ))
        }

        let preview = MiniGraphPreview(session: session, preloadedNodes: nodes)
        let hosting = NSHostingView(rootView: preview)
        hosting.frame = CGRect(x: 0, y: 0, width: 230, height: 125)
        hosting.layoutSubtreeIfNeeded()

        let start = ContinuousClock.now
        let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds)
        let elapsed = ContinuousClock.now - start

        #expect(rep != nil)
        #expect(rep?.size == CGSize(width: 230, height: 125))
        #expect(elapsed < .milliseconds(300))
    }

    @Test("MiniGraphPreview memory and render latency benchmark across 0, 1, 1000 nodes")
    @MainActor
    func testMiniGraphPreviewBenchmark() {
        func getResidentMemoryKB() -> UInt64 {
            var info = mach_task_basic_info()
            var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
            let kerr = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                    task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
                }
            }
            return kerr == KERN_SUCCESS ? info.resident_size / 1024 : 0
        }

        let initialMem = getResidentMemoryKB()

        // 1. Benchmark 0 nodes
        let s0 = BrowsingSession(id: UUID(), title: "Zero", startTime: Date())
        let p0 = MiniGraphPreview(session: s0, preloadedNodes: [])
        let h0 = NSHostingView(rootView: p0)
        h0.frame = CGRect(x: 0, y: 0, width: 230, height: 125)
        h0.layoutSubtreeIfNeeded()
        let t0Start = ContinuousClock.now
        let r0 = h0.bitmapImageRepForCachingDisplay(in: h0.bounds)
        let t0Elapsed = ContinuousClock.now - t0Start
        #expect(r0 != nil)

        // 2. Benchmark 1 node
        let s1 = BrowsingSession(id: UUID(), title: "One", startTime: Date())
        let n1 = BrowsingNode(sessionId: s1.id, url: "https://apple.com", title: "Apple", branchLevel: 0)
        let p1 = MiniGraphPreview(session: s1, preloadedNodes: [n1])
        let h1 = NSHostingView(rootView: p1)
        h1.frame = CGRect(x: 0, y: 0, width: 230, height: 125)
        h1.layoutSubtreeIfNeeded()
        let t1Start = ContinuousClock.now
        let r1 = h1.bitmapImageRepForCachingDisplay(in: h1.bounds)
        let t1Elapsed = ContinuousClock.now - t1Start
        #expect(r1 != nil)

        // 3. Benchmark 1,000 nodes
        let s1000 = BrowsingSession(id: UUID(), title: "Thousand", startTime: Date())
        var nodes1000: [BrowsingNode] = []
        nodes1000.reserveCapacity(1000)
        var parentId: UUID? = nil
        for i in 0..<1000 {
            let n = BrowsingNode(
                sessionId: s1000.id,
                url: "https://example.com/\(i)",
                title: "Node \(i)",
                parentNodeId: parentId,
                branchLevel: i % 8,
                orderIndex: i
            )
            nodes1000.append(n)
            if i % 5 == 0 { parentId = n.id }
        }

        let p1000 = MiniGraphPreview(session: s1000, preloadedNodes: nodes1000)
        let h1000 = NSHostingView(rootView: p1000)
        h1000.frame = CGRect(x: 0, y: 0, width: 230, height: 125)
        h1000.layoutSubtreeIfNeeded()
        let t1000Start = ContinuousClock.now
        let r1000 = h1000.bitmapImageRepForCachingDisplay(in: h1000.bounds)
        let t1000Elapsed = ContinuousClock.now - t1000Start
        #expect(r1000 != nil)

        let finalMem = getResidentMemoryKB()
        let memGrowth = finalMem > initialMem ? finalMem - initialMem : 0

        print("""
        [BENCHMARK RESULTS]
        - 0 nodes render latency: \(t0Elapsed)
        - 1 node render latency: \(t1Elapsed)
        - 1,000 nodes render latency: \(t1000Elapsed)
        - Memory delta: \(memGrowth) KB (initial: \(initialMem) KB, final: \(finalMem) KB)
        """)

        // Strict thresholds:
        // 0 nodes: < 20ms
        // 1 node: < 20ms
        // 1000 nodes: < 250ms
        // Memory delta: < 50MB (51,200 KB)
        #expect(t0Elapsed < .milliseconds(20))
        #expect(t1Elapsed < .milliseconds(20))
        #expect(t1000Elapsed < .milliseconds(250))
        #expect(memGrowth < 51_200)
    }

    @Test("MiniGraphPreview pixel raster verification: confirms canvas executes and paints pixels")
    @MainActor
    func testMiniGraphPreviewPixelRasterVerification() {
        let session = BrowsingSession(id: UUID(), title: "Pixel Test", startTime: Date())
        let node = BrowsingNode(sessionId: session.id, url: "https://example.com", title: "Single", branchLevel: 0)
        let preview = MiniGraphPreview(session: session, preloadedNodes: [node])
            .frame(width: 200, height: 100)

        let renderer = ImageRenderer(content: preview)
        guard let nsImage = renderer.nsImage,
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            Issue.record("Failed to render ImageRenderer image")
            return
        }

        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixelData = [UInt8](repeating: 0, count: width * height * 4)
        let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var paintedPixels = 0
        for i in stride(from: 3, to: pixelData.count, by: 4) {
            if pixelData[i] > 10 { // Alpha > 10
                paintedPixels += 1
            }
        }
        print("ImageRenderer 1 node pixel count: width=\(width), height=\(height), paintedPixels=\(paintedPixels)")
        #expect(paintedPixels > 0, "Canvas must paint visible pixels for 1 node")

        // 2. Empty session: baseline path must paint visible pixels
        let emptyPreview = MiniGraphPreview(session: session, preloadedNodes: [])
            .frame(width: 200, height: 100)
        let emptyRenderer = ImageRenderer(content: emptyPreview)
        guard let emptyImage = emptyRenderer.nsImage,
              let emptyCGImage = emptyImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            Issue.record("Failed to render empty ImageRenderer image")
            return
        }
        var emptyPixels = [UInt8](repeating: 0, count: emptyCGImage.width * emptyCGImage.height * 4)
        let emptyContext = CGContext(
            data: &emptyPixels,
            width: emptyCGImage.width,
            height: emptyCGImage.height,
            bitsPerComponent: 8,
            bytesPerRow: emptyCGImage.width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        emptyContext?.draw(emptyCGImage, in: CGRect(x: 0, y: 0, width: emptyCGImage.width, height: emptyCGImage.height))
        var emptyPainted = 0
        for i in stride(from: 3, to: emptyPixels.count, by: 4) {
            if emptyPixels[i] > 10 { emptyPainted += 1 }
        }
        print("ImageRenderer 0 nodes pixel count: paintedPixels=\(emptyPainted)")
        #expect(emptyPainted > 0, "Canvas must paint baseline pixels for 0 nodes")

        // 3. 1,000 nodes: dense graph must paint significantly more pixels
        var thousandNodes: [BrowsingNode] = []
        for i in 0..<1000 {
            thousandNodes.append(BrowsingNode(
                sessionId: session.id,
                url: "https://example.com/\(i)",
                title: "Node \(i)",
                branchLevel: i % 10,
                orderIndex: i
            ))
        }
        let thousandPreview = MiniGraphPreview(session: session, preloadedNodes: thousandNodes)
            .frame(width: 200, height: 100)
        let thousandRenderer = ImageRenderer(content: thousandPreview)
        guard let thousandImage = thousandRenderer.nsImage,
              let thousandCGImage = thousandImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            Issue.record("Failed to render 1000 nodes ImageRenderer image")
            return
        }
        var thousandPixels = [UInt8](repeating: 0, count: thousandCGImage.width * thousandCGImage.height * 4)
        let thousandContext = CGContext(
            data: &thousandPixels,
            width: thousandCGImage.width,
            height: thousandCGImage.height,
            bitsPerComponent: 8,
            bytesPerRow: thousandCGImage.width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        thousandContext?.draw(thousandCGImage, in: CGRect(x: 0, y: 0, width: thousandCGImage.width, height: thousandCGImage.height))
        var thousandPainted = 0
        for i in stride(from: 3, to: thousandPixels.count, by: 4) {
            if thousandPixels[i] > 10 { thousandPainted += 1 }
        }
        print("ImageRenderer 1,000 nodes pixel count: paintedPixels=\(thousandPainted)")
        #expect(thousandPainted > paintedPixels, "1,000 nodes must paint more pixels than a single node")
    }
}
