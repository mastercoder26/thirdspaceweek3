import Foundation
import AppKit

public final class ChromiumTracker: BrowserTrackerProtocol, @unchecked Sendable {
    public let browserName: String
    public let appName: String
    public let bundleIdentifiers: [String]

    public init(browserName: String, appName: String, bundleIdentifiers: [String]) {
        self.browserName = browserName
        self.appName = appName
        self.bundleIdentifiers = bundleIdentifiers
    }

    private func activeBundleIdentifier() -> String {
        if let frontApp = NSWorkspace.shared.frontmostApplication,
           let bid = frontApp.bundleIdentifier,
           bundleIdentifiers.contains(bid) {
            return bid
        }
        let runningApps = NSWorkspace.shared.runningApplications
        for app in runningApps {
            if let bid = app.bundleIdentifier, bundleIdentifiers.contains(bid) {
                return bid
            }
        }
        return bundleIdentifiers.first ?? appName
    }

    public func isRunning() -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        return runningApps.contains { app in
            if let bid = app.bundleIdentifier, bundleIdentifiers.contains(bid) {
                return true
            }
            if let name = app.localizedName, name.lowercased() == appName.lowercased() {
                return true
            }
            return false
        }
    }

    public func isFrontmost() -> Bool {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return false }
        if let bid = frontApp.bundleIdentifier, bundleIdentifiers.contains(bid) {
            return true
        }
        if let name = frontApp.localizedName, name.lowercased() == appName.lowercased() {
            return true
        }
        return false
    }

    public func fetchActiveTab() async -> BrowserTabInfo? {
        guard isRunning() else { return nil }

        let targetId = activeBundleIdentifier()
        let targetClause = targetId.contains(".") ? "application id \"\(targetId)\"" : "application \"\(targetId)\""
        let script = """
        with timeout of 2 seconds
            tell \(targetClause)
                try
                    if (count of windows) > 0 then
                        set frontWin to front window
                        set winId to id of frontWin as text
                        set curTab to active tab of frontWin
                        set tabId to id of curTab as text
                        set tabUrl to URL of curTab
                        set tabTitle to title of curTab
                        if tabUrl is missing value then
                            set tabUrl to ""
                        end if
                        if tabTitle is missing value then
                            set tabTitle to ""
                        end if
                        return winId & "|||" & tabId & "|||" & tabUrl & "|||" & tabTitle
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
        guard parts.count >= 4 else { return nil }

        let winId = parts[0].trimmingCharacters(in: .whitespaces)
        let tabId = parts[1].trimmingCharacters(in: .whitespaces)
        let url = parts[2].trimmingCharacters(in: .whitespaces)
        let title = parts.dropFirst(3).joined(separator: "|||").trimmingCharacters(in: .whitespaces)

        // Filter out empty, missing value, or internal browser URLs
        if url.isEmpty || url == "missing value" || url == "chrome://newtab/" || url == "about:blank" || url.hasPrefix("chrome://") {
            return nil
        }

        return BrowserTabInfo(
            windowId: winId,
            tabId: tabId,
            url: url,
            title: title,
            browserName: self.browserName
        )
    }
}
