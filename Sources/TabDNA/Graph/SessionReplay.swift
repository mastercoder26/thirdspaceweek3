import Foundation
import Observation

/// Replay uses recorded pages rather than elapsed time, so a long pause cannot
/// hide the next page and pages with the same timestamp still get their own step.
struct SessionReplaySequence {
    let pages: [BrowsingNode]

    init(nodes: [BrowsingNode]) {
        pages = nodes.sorted {
            if $0.timestampOpened != $1.timestampOpened { return $0.timestampOpened < $1.timestampOpened }
            if $0.orderIndex != $1.orderIndex { return $0.orderIndex < $1.orderIndex }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    func page(at index: Int) -> BrowsingNode? {
        pages.indices.contains(index) ? pages[index] : nil
    }

    func previousPage(at index: Int) -> BrowsingNode? {
        page(at: index - 1)
    }

    func connection(to page: BrowsingNode) -> BrowsingNode? {
        pages.first { $0.id == page.parentNodeId }
    }
}

@MainActor @Observable
final class SessionReplay {
    enum Phase { case overview, paused, playing, finished }

    private(set) var pageIDs: [UUID] = []
    private(set) var index = 0
    private(set) var phase: Phase = .overview
    private(set) var generation = 0
    var followsPage = true
    var speed: Double = 1 {
        didSet { if speed != oldValue { generation += 1 } }
    }
    var stepInterval: TimeInterval { 2.4 / max(0.5, min(2, speed)) }
    var isPlaying: Bool { phase == .playing }
    var isOverview: Bool { phase == .overview }
    var focusedPageID: UUID? { isOverview || pageIDs.isEmpty ? nil : pageIDs[index] }
    var visiblePageIDs: Set<UUID> {
        Set(isOverview ? pageIDs : Array(pageIDs.prefix(index + 1)))
    }

    func reconcile(_ sequence: SessionReplaySequence) {
        let ids = sequence.pages.map(\.id)
        guard ids != pageIDs else { return }
        let focusedID = focusedPageID
        pageIDs = ids
        if let focusedID, let preservedIndex = ids.firstIndex(of: focusedID) {
            index = preservedIndex
        } else {
            index = min(index, max(0, ids.count - 1))
            pause()
        }
        if isOverview { index = max(0, ids.count - 1) }
        if ids.isEmpty { showAll() }
    }

    func play() {
        guard !pageIDs.isEmpty else { return }
        if isOverview || index == pageIDs.count - 1 { index = 0 }
        followsPage = true
        phase = pageIDs.count > 1 ? .playing : .finished
        generation += 1
    }

    func pause() {
        guard isPlaying else { return }
        phase = .paused
        generation += 1
    }

    func seek(to requestedIndex: Int) {
        guard !pageIDs.isEmpty else { return }
        index = min(max(0, requestedIndex), pageIDs.count - 1)
        phase = .paused
        generation += 1
    }

    func step(_ delta: Int) { seek(to: index + delta) }

    func showAll() {
        phase = .overview
        index = max(0, pageIDs.count - 1)
        generation += 1
    }

    func advance(generation expectedGeneration: Int) {
        guard isPlaying, generation == expectedGeneration else { return }
        index = min(index + 1, pageIDs.count - 1)
        if index == pageIDs.count - 1 { phase = .finished }
    }

    func takeControl() { pause(); followsPage = false }
}
