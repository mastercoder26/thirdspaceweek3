import AppKit
import Foundation

public final class SafariTracker: BrowserTrackerProtocol, @unchecked Sendable {
    public let browserName: String = "Safari"
    public let bundleIdentifiers: [String] = [
        "com.apple.Safari",
        "com.apple.SafariTechnologyPreview",
    ]

    private struct TrackedTabSlot {
        let stableId: String
        var lastIndex: Int
        var lastUrl: String
        var lastSeen: Date
    }

    private var windowTabs: [String: [TrackedTabSlot]] = [:]
    private let lock = NSLock()

    public init() {}

    private func activeBundleIdentifier() -> String {
        if let frontApp = NSWorkspace.shared.frontmostApplication,
            let bid = frontApp.bundleIdentifier,
            bundleIdentifiers.contains(bid)
        {
            return bid
        }
        let runningApps = NSWorkspace.shared.runningApplications
        for app in runningApps {
            if let bid = app.bundleIdentifier, bundleIdentifiers.contains(bid) {
                return bid
            }
        }
        return bundleIdentifiers.first ?? "com.apple.Safari"
    }

    public func isRunning() -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        return runningApps.contains { app in
            guard let bid = app.bundleIdentifier else { return false }
            return bundleIdentifiers.contains(bid)
        }
    }

    public func isFrontmost() -> Bool {
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
            let bid = frontApp.bundleIdentifier
        else { return false }
        return bundleIdentifiers.contains(bid)
    }

    private func resolveStableTabId(windowId: String, tabIndex: Int, tabCount: Int, url: String) -> String {
        lock.lock()
        defer { lock.unlock() }

        var slots = windowTabs[windowId] ?? []
        let cleanUrl = BrowserVisitResolver.canonicalUrl(url)

        // Match the URL before the index: closing another tab can move this one.
        if let idx = slots.firstIndex(where: { BrowserVisitResolver.canonicalUrl($0.lastUrl) == cleanUrl }) {
            slots[idx].lastIndex = tabIndex
            slots[idx].lastSeen = Date()
            let stableId = slots[idx].stableId
            windowTabs[windowId] = slots
            return stableId
        }

        // The same slot with a different URL is a navigation.
        if let idx = slots.firstIndex(where: { $0.lastIndex == tabIndex }) {
            slots[idx].lastUrl = url
            slots[idx].lastSeen = Date()
            let stableId = slots[idx].stableId
            windowTabs[windowId] = slots
            return stableId
        }

        let newStableId = "safari-tab-" + UUID().uuidString
        let newSlot = TrackedTabSlot(
            stableId: newStableId, lastIndex: tabIndex, lastUrl: url, lastSeen: Date())
        slots.append(newSlot)

        // Discard slots left behind by closed tabs.
        if slots.count > max(tabCount, 1) {
            slots.sort(by: { $0.lastSeen > $1.lastSeen })
            slots = Array(slots.prefix(max(tabCount, 1)))
        }

        windowTabs[windowId] = slots
        return newStableId
    }

    public func fetchActiveTab() async -> BrowserTabInfo? {
        guard isRunning() else { return nil }

        let targetBundleId = activeBundleIdentifier()
        let script = """
            with timeout of 2 seconds
                tell application id "\(targetBundleId)"
                    try
                        if (count of windows) > 0 then
                            set frontWin to front window
                            set winId to id of frontWin as text
                            set curTab to current tab of frontWin
                            set tabIdx to (index of curTab as text)
                            set tabCount to (count of tabs of frontWin as text)
                            set tabUrl to URL of curTab
                            set tabTitle to name of curTab
                            if tabUrl is missing value then
                                set tabUrl to ""
                            end if
                            if tabTitle is missing value then
                                set tabTitle to ""
                            end if
                            return winId & "|||" & tabIdx & "|||" & tabCount & "|||" & tabUrl & "|||" & tabTitle
                        else
                            return ""
                        end if
                    on error
                        return ""
                    end try
                end tell
            end timeout
            """

        guard let output = await AppleScriptRunner.run(script: script) else {
            return nil
        }

        let parts = output.components(separatedBy: "|||")
        guard parts.count >= 5 else { return nil }

        let winId = parts[0].trimmingCharacters(in: .whitespaces)
        let tabIdx = Int(parts[1].trimmingCharacters(in: .whitespaces)) ?? 1
        let tabCount = Int(parts[2].trimmingCharacters(in: .whitespaces)) ?? 1
        let url = parts[3].trimmingCharacters(in: .whitespaces)
        let title = parts.dropFirst(4).joined(separator: "|||").trimmingCharacters(in: .whitespaces)

        if url.isEmpty || url == "missing value" || url == "favorites://"
            || url.hasPrefix("safari-resource://") || url == "about:blank"
        {
            return nil
        }

        let stableTabId = resolveStableTabId(windowId: winId, tabIndex: tabIdx, tabCount: tabCount, url: url)

        return BrowserTabInfo(
            windowId: winId,
            tabId: stableTabId,
            url: url,
            title: title,
            browserName: self.browserName
        )
    }
}
