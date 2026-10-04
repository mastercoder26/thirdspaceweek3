import Testing
import Foundation
@testable import TabDNA

@Suite("Session playback")
struct SessionReplayTests {
    // Scaffold: build a small session with a long gap and a shared parent.
    private func pages() -> [BrowsingNode] {
        let session = UUID()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let first = BrowsingNode(sessionId: session, url: "https://example.com/start", title: "Start", timestampOpened: start, orderIndex: 0)
        let second = BrowsingNode(sessionId: session, url: "https://example.com/second", title: "Second", timestampOpened: start, parentNodeId: first.id, orderIndex: 1)
        let third = BrowsingNode(sessionId: session, url: "https://example.com/third", title: "Third", timestampOpened: start.addingTimeInterval(7200), tabId: "2", parentNodeId: first.id, orderIndex: 2)
        return [first, second, third]
    }

    @Test("Replay orders simultaneous pages and reveals each one despite long gaps") @MainActor
    func visitsAreIndividualSteps() {
        let pages = pages()
        let sequence = SessionReplaySequence(nodes: pages.reversed())
        #expect(sequence.pages.map(\.id) == pages.map(\.id))
        #expect(sequence.connection(to: pages[2])?.id == pages[0].id)
        #expect(sequence.previousPage(at: 0) == nil)
        let replay = SessionReplay()
        replay.reconcile(sequence)
        #expect(replay.visiblePageIDs.count == 3)
        replay.play()
        #expect(replay.visiblePageIDs == [pages[0].id])
        replay.advance(generation: replay.generation)
        #expect(replay.focusedPageID == pages[1].id)
        #expect(replay.visiblePageIDs.count == 2)
        replay.advance(generation: replay.generation)
        #expect(replay.focusedPageID == pages[2].id)
        #expect(replay.phase == .finished)
        #expect(replay.visiblePageIDs.count == 3)
        replay.play()
        #expect(replay.index == 0)
    }

    @Test("Paused, scrubbed, and speed-changed playback ignores stale tasks") @MainActor
    func cancelledTicksCannotAdvance() {
        let replay = SessionReplay()
        replay.reconcile(SessionReplaySequence(nodes: pages()))
        replay.play()
        let originalGeneration = replay.generation
        replay.pause()
        replay.advance(generation: originalGeneration)
        #expect(replay.index == 0)
        replay.play()
        let resumedGeneration = replay.generation
        replay.seek(to: 1)
        replay.advance(generation: resumedGeneration)
        #expect(replay.index == 1)
        #expect(!replay.isPlaying)
        replay.play()
        let previousSpeedGeneration = replay.generation
        replay.speed = 2
        replay.advance(generation: previousSpeedGeneration)
        #expect(replay.index == 1)
        #expect(replay.stepInterval == 1.2)
    }

    @Test("Live updates preserve replay position and never reveal future pages early") @MainActor
    func updatesKeepTheCurrentPage() {
        let pages = pages()
        let replay = SessionReplay()
        replay.reconcile(SessionReplaySequence(nodes: Array(pages.prefix(2))))
        replay.seek(to: 0)
        replay.reconcile(SessionReplaySequence(nodes: pages))
        #expect(replay.focusedPageID == pages[0].id)
        #expect(replay.visiblePageIDs.count == 1)
        replay.showAll()
        #expect(replay.visiblePageIDs.count == 3)
        #expect(replay.focusedPageID == nil)
    }

    @Test("Manual navigation pauses playback and gives camera control to the user") @MainActor
    func manualControlAndSeeking() {
        let replay = SessionReplay()
        replay.reconcile(SessionReplaySequence(nodes: pages()))
        replay.play()
        replay.takeControl()
        #expect(!replay.isPlaying)
        #expect(!replay.followsPage)
        replay.seek(to: 999)
        #expect(replay.index == 2)
        replay.seek(to: -99)
        #expect(replay.index == 0)
        replay.play()
        #expect(replay.followsPage)
        #expect(replay.isPlaying)
    }

    @Test("Empty, single-page, and removed-page sessions remain safe") @MainActor
    func smallAndChangingSessions() {
        let replay = SessionReplay()
        replay.play()
        replay.seek(to: 99)
        #expect(replay.focusedPageID == nil)
        let pages = pages()
        replay.reconcile(SessionReplaySequence(nodes: [pages[0]]))
        replay.play()
        #expect(replay.phase == .finished)
        #expect(replay.focusedPageID == pages[0].id)
        replay.reconcile(SessionReplaySequence(nodes: pages))
        replay.seek(to: 2)
        replay.reconcile(SessionReplaySequence(nodes: [pages[0]]))
        #expect(replay.index == 0)
        #expect(replay.focusedPageID == pages[0].id)
        replay.reconcile(SessionReplaySequence(nodes: []))
        #expect(replay.isOverview)
        #expect(replay.visiblePageIDs.isEmpty)
    }
}
