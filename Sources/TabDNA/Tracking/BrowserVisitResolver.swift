import Foundation

private struct TabIdentity: Hashable {
    let browser: String
    let window: String
    let tab: String
    init(_ info: BrowserTabInfo) { browser = info.browserName; window = info.windowId; tab = info.tabId }
}

struct BrowserVisitResolver {
    private var pagesByTab: [TabIdentity: UUID] = [:]
    private var lastPageId: UUID?

    func resolve(tab: BrowserTabInfo, url: String, sessionId: UUID, lookup: (UUID) -> BrowsingNode?) -> (existing: BrowsingNode?, parent: BrowsingNode?) {
        let previous = pagesByTab[TabIdentity(tab)].flatMap(lookup).flatMap { $0.sessionId == sessionId ? $0 : nil }
        if let previous, previous.url == url { return (previous, nil) }
        let last = lastPageId.flatMap(lookup).flatMap { $0.sessionId == sessionId ? $0 : nil }
        return (nil, previous ?? last)
    }

    mutating func record(_ node: BrowsingNode, tab: BrowserTabInfo) {
        pagesByTab[TabIdentity(tab)] = node.id
        lastPageId = node.id
    }

    mutating func clearActivePage() { lastPageId = nil }
    mutating func reset() { pagesByTab.removeAll(); lastPageId = nil }
}
