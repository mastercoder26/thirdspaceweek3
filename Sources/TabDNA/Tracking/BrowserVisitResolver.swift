import Foundation

public struct WindowScope: Hashable, Sendable {
    public let browser: String
    public let window: String

    public init(browser: String, window: String) {
        self.browser = browser
        self.window = window
    }

    public init(_ info: BrowserTabInfo) {
        self.browser = info.browserName
        self.window = info.windowId
    }
}

public struct TabIdentity: Hashable, Sendable {
    public let browser: String
    public let window: String
    public let tab: String

    public init(browser: String, window: String, tab: String) {
        self.browser = browser
        self.window = window
        self.tab = tab
    }

    public init(_ info: BrowserTabInfo) {
        self.browser = info.browserName
        self.window = info.windowId
        self.tab = info.tabId
    }
}

public struct BrowserVisitResolver {
    private var pagesByTab: [TabIdentity: UUID] = [:]
    private var lastPageByWindow: [WindowScope: UUID] = [:]

    public init() {}

    public static func canonicalUrl(_ url: String) -> String {
        if let hashIndex = url.firstIndex(of: "#") {
            return String(url[..<hashIndex])
        }
        return url
    }

    public func resolve(
        tab: BrowserTabInfo,
        url: String,
        sessionId: UUID,
        lookup: (UUID) -> BrowsingNode?
    ) -> (existing: BrowsingNode?, parent: BrowsingNode?) {
        let cleanUrl = Self.canonicalUrl(url)
        let tabKey = TabIdentity(tab)
        let windowScope = WindowScope(tab)

        let previous = pagesByTab[tabKey].flatMap(lookup).flatMap { $0.sessionId == sessionId ? $0 : nil }
        if let previous {
            if previous.url == url || Self.canonicalUrl(previous.url) == cleanUrl {
                return (previous, nil)
            }
        }

        // Closing a tab can shift Safari’s tab indices. Reuse a matching visit in this window.
        let windowMatches = pagesByTab.filter { key, _ in
            key.browser == tab.browserName && key.window == tab.windowId
        }
        if let shifted =
            windowMatches.compactMap({ key, nodeId -> BrowsingNode? in
                guard let node = lookup(nodeId), node.sessionId == sessionId else { return nil }
                return (node.url == url || Self.canonicalUrl(node.url) == cleanUrl) ? node : nil
            })
            .first
        {
            return (shifted, nil)
        }

        // Going back to an ancestor reuses that visit rather than adding a duplicate page.
        if let previous {
            var currentParentId = previous.parentNodeId
            var visitedAncestors = Set<UUID>()
            while let pId = currentParentId, !visitedAncestors.contains(pId) {
                visitedAncestors.insert(pId)
                if let ancestor = lookup(pId), ancestor.sessionId == sessionId {
                    if ancestor.url == url || Self.canonicalUrl(ancestor.url) == cleanUrl {
                        return (ancestor, nil)
                    }
                    currentParentId = ancestor.parentNodeId
                } else {
                    break
                }
            }
        }

        // New visits follow this tab’s last page, then fall back to the active page in the same window.
        let lastInWindow = lastPageByWindow[windowScope].flatMap(lookup)
            .flatMap { $0.sessionId == sessionId ? $0 : nil }
        return (nil, previous ?? lastInWindow)
    }

    public mutating func record(_ node: BrowsingNode, tab: BrowserTabInfo) {
        let newKey = TabIdentity(tab)
        let windowScope = WindowScope(tab)

        // A reused visit must not remain attached to its old tab index.
        for (oldKey, existingNodeId) in pagesByTab
        where existingNodeId == node.id && oldKey.browser == tab.browserName && oldKey.window == tab.windowId
            && oldKey.tab != tab.tabId
        {
            pagesByTab.removeValue(forKey: oldKey)
        }

        pagesByTab[newKey] = node.id
        lastPageByWindow[windowScope] = node.id
    }

    public mutating func clearActivePage(for scope: WindowScope? = nil) {
        if let scope {
            lastPageByWindow.removeValue(forKey: scope)
        } else {
            lastPageByWindow.removeAll()
        }
    }

    public mutating func reset() {
        pagesByTab.removeAll()
        lastPageByWindow.removeAll()
    }
}
