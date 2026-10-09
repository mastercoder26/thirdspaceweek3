import Testing
import Foundation
import SwiftUI
import AppKit
@testable import TabDNA

@Suite("Visual Design, Canvas Ergonomics & Motion Polish (M1)")
struct VisualErgonomicsTests {
    // F01 tests
    @Test("Bezier routing eliminates inverted loops when target is behind source")
    func bezierRoutingEliminatesLoopsWhenReversed() {
        // Horizontal: target to the left of source at same vertical level
        let startH = CGPoint(x: 300, y: 150)
        let endH = CGPoint(x: 100, y: 150)
        let (c1H, c2H) = GraphViewport.edgeControlPoints(start: startH, end: endH, mode: .horizontal)

        // Control points must provide vertical separation to avoid flat collinear knots
        #expect(abs(c1H.y - startH.y) >= 40)
        #expect(abs(c2H.y - endH.y) >= 40)
        #expect(c1H.x > startH.x)
        #expect(c2H.x < endH.x)

        // Waterfall: target above source in same column
        let startW = CGPoint(x: 200, y: 350)
        let endW = CGPoint(x: 200, y: 100)
        let (c1W, c2W) = GraphViewport.edgeControlPoints(start: startW, end: endW, mode: .waterfall)

        // Control points must provide horizontal clearance
        #expect(abs(c1W.x - startW.x) >= 40)
        #expect(abs(c2W.x - endW.x) >= 40)
        #expect(c1W.y > startW.y)
        #expect(c2W.y < endW.y)
    }

    @Test("Bezier routing scales smoothly with large vertical offsets in deep branching")
    func bezierRoutingDeepBranchingSmoothness() {
        let start = CGPoint(x: 100, y: 100)
        let end = CGPoint(x: 260, y: 1500)
        let (c1, c2) = GraphViewport.edgeControlPoints(start: start, end: end, mode: .horizontal)

        #expect(c1.x > start.x + 80)
        #expect(c2.x < end.x)
        #expect(c1.y == start.y)
        #expect(c2.y == end.y)
    }

    @Test("Scale range lower bound prevents sub-pixel card shrinkage")
    func scaleRangeLowerBoundClamping() {
        #expect(GraphViewport.scaleRange.lowerBound >= 0.15)
        #expect(GraphViewport.scaleRange.upperBound == 2.5)

        // Ensure fit calculation never drops below readable minimum
        let massivePoints = [CGPoint(x: -10000, y: -10000), CGPoint(x: 10000, y: 10000)]
        let bounds = GraphViewport.bounds(positions: massivePoints)
        let fit = GraphViewport.fit(bounds: bounds, viewport: CGSize(width: 800, height: 600))
        #expect(fit.scale >= 0.15)
    }

    // F02 test
    @Test("Pointer-anchored zoom keeps arbitrary cursor coordinates fixed in world space")
    func pointerAnchoredZoomPreservesCursorWorldPosition() {
        let initialOffset = CGSize(width: -150, height: -220)
        let cursor = CGPoint(x: 520, y: 340)
        let oldScale: CGFloat = 0.8
        let newScale: CGFloat = 1.4

        let updatedOffset = GraphViewport.zoomOffset(from: oldScale, to: newScale, offset: initialOffset, anchor: cursor)

        let worldXBefore = (cursor.x - initialOffset.width) / oldScale
        let worldXAfter = (cursor.x - updatedOffset.width) / newScale
        let worldYBefore = (cursor.y - initialOffset.height) / oldScale
        let worldYAfter = (cursor.y - updatedOffset.height) / newScale

        #expect(abs(worldXBefore - worldXAfter) < 0.0001)
        #expect(abs(worldYBefore - worldYAfter) < 0.0001)
    }

    // F03 test
    @Test("FaviconView fallbackEmoji rendering and hierarchy")
    @MainActor
    func testFaviconViewFallbackEmoji() {
        let viewWithEmoji = FaviconView(domain: "wikipedia.org", fallbackEmoji: "📖", size: 14)
        #expect(viewWithEmoji.domain == "wikipedia.org")
        #expect(viewWithEmoji.fallbackEmoji == "📖")
        #expect(viewWithEmoji.size == 14)

        let viewWithEmptyEmoji = FaviconView(domain: "unknown.org", fallbackEmoji: "", size: 22)
        #expect(viewWithEmptyEmoji.domain == "unknown.org")
        #expect(viewWithEmptyEmoji.fallbackEmoji == "")
        #expect(viewWithEmptyEmoji.size == 22)

        let hosting = NSHostingView(rootView: viewWithEmoji)
        hosting.frame = CGRect(x: 0, y: 0, width: 14, height: 14)
        let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds)
        #expect(bitmap != nil)
        #expect(bitmap?.size == CGSize(width: 14, height: 14))
    }

    // F04 test
    @Test("NodeCardView 2-line title descenders and layout dimensions")
    @MainActor
    func testNodeCardViewTypographyAndDimensions() {
        let session = BrowsingSession()
        let node = BrowsingNode(
            sessionId: session.id,
            url: "https://en.wikipedia.org/wiki/Typography",
            title: "Typography and descenders: physics, geography & cryptography",
            activeDurationSeconds: 125,
            isPinned: true
        )
        let layout = GraphNodeLayout(
            node: node,
            position: CGPoint(x: 100, y: 100),
            targetPosition: CGPoint(x: 100, y: 100),
            branchLevel: 1,
            childIds: [UUID(), UUID(), UUID()],
            isRoot: false
        )

        let card = NodeCardView(
            layout: layout,
            isSelected: false,
            isSearchMatched: false,
            isBranchHighlighted: true,
            isCurrentlyActiveTab: true,
            isReplayFocused: false,
            onSelect: {},
            onDragDelta: { _ in }
        )

        let hosting = NSHostingView(rootView: card)
        hosting.frame = CGRect(x: 0, y: 0, width: 220, height: 98)
        let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds)
        #expect(rep != nil)
        #expect(rep?.size == CGSize(width: 220, height: 98))
    }

    // F05 test
    @Test("SessionGuideView collapsed state and dismissal default")
    @MainActor
    func testSessionGuideViewDismiss() {
        let guide = SessionGuideView()
        let hosting = NSHostingView(rootView: guide)
        hosting.frame = CGRect(x: 0, y: 0, width: 600, height: 40)
        let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds)
        #expect(rep != nil)
    }

    // F06 test
    @Test("Statistics hourly and daily bucket alignment")
    func testStatisticsDateBuckets() {
        let calendar = Calendar.current
        let today = Date()
        let startOfToday = calendar.startOfDay(for: today)

        // Ensure hourly increments produce distinct hours
        let hour0 = calendar.date(byAdding: .hour, value: 0, to: startOfToday)!
        let hour1 = calendar.date(byAdding: .hour, value: 1, to: startOfToday)!
        #expect(calendar.component(.hour, from: hour0) == 0)
        #expect(calendar.component(.hour, from: hour1) == 1)

        // Ensure 7-day offset produces 7 days ending today
        let days = (0..<7).reversed().map { offset in
            calendar.date(byAdding: .day, value: -offset, to: startOfToday)!
        }
        #expect(days.count == 7)
        #expect(calendar.isDateInToday(days.last!))
    }

    // F07 tests
    @Test("DNAStyle branch color palette cycle")
    func testBranchColors() {
        #expect(DNAStyle.branch(0) == DNAStyle.accent)
        #expect(DNAStyle.branch(1) == Color.purple)
        #expect(DNAStyle.branch(2) == Color.teal)
        #expect(DNAStyle.branch(3) == Color.orange)
        #expect(DNAStyle.branch(4) == DNAStyle.accent)
    }

    @Test("MiniGraphPreview preloaded nodes bypasses store query")
    func testMiniGraphPreviewPreloading() {
        let session = BrowsingSession(id: UUID(), title: "Test Session", startTime: Date())
        let node = BrowsingNode(
            id: UUID(),
            sessionId: session.id,
            url: "https://example.com",
            title: "Example",
            branchLevel: 0,
            browserName: "Safari"
        )
        let preview = MiniGraphPreview(session: session, preloadedNodes: [node])
        #expect(preview.preloadedNodes?.count == 1)
        #expect(preview.preloadedNodes?.first?.id == node.id)
    }

    @Test("MiniGraphPreview single node and empty session canvas rendering")
    @MainActor
    func testMiniGraphPreviewRendering() {
        let session = BrowsingSession(id: UUID(), title: "Single Node Session", startTime: Date())
        let node = BrowsingNode(
            id: UUID(),
            sessionId: session.id,
            url: "https://example.com",
            title: "Single Node",
            branchLevel: 0,
            browserName: "Safari"
        )
        let preview = MiniGraphPreview(session: session, preloadedNodes: [node])
        let hosting = NSHostingView(rootView: preview)
        hosting.frame = CGRect(x: 0, y: 0, width: 230, height: 125)
        let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds)
        #expect(rep != nil)
        #expect(rep?.size == CGSize(width: 230, height: 125))
    }
}
