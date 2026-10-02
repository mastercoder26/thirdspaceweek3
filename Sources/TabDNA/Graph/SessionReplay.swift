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
}

@MainActor @Observable
final class SessionReplay {
    enum Phase { case overview, paused, playing, finished }

    private(set) var pageIDs: [UUID] = []
    private(set) var index = 0
    private(set) var phase: Phase = .overview
    var followsPage = true
    var speed: Double = 1

    var isPlaying: Bool { phase == .playing }
    var isOverview: Bool { phase == .overview }
    var focusedPageID: UUID? { isOverview || pageIDs.isEmpty ? nil : pageIDs[index] }
    var visiblePageIDs: Set<UUID> {
        Set(isOverview ? pageIDs : Array(pageIDs.prefix(index + 1)))
    }

    func reconcile(_ sequence: SessionReplaySequence) {
        let ids = sequence.pages.map(\.id)
        guard ids != pageIDs else { return }
        pageIDs = ids
        index = min(index, max(0, ids.count - 1))
        if isOverview { index = max(0, ids.count - 1) }
        if ids.isEmpty { phase = .overview; index = 0 }
    }

    func play() {
        guard !pageIDs.isEmpty else { return }
        if isOverview || index == pageIDs.count - 1 { index = 0 }
        followsPage = true
        phase = pageIDs.count > 1 ? .playing : .finished
    }

    func pause() {
        guard isPlaying else { return }
        phase = .paused
    }
}
