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

        let script = """
        tell application "\(appName)"
            if (count of windows) > 0 then
                set frontWin to front window
                set winId to id of frontWin as text
                set curTab to active tab of frontWin
                set tabId to id of curTab as text
                set tabUrl to URL of curTab
                set tabTitle to title of curTab
                return winId & "|||" & tabId & "|||" & tabUrl & "|||" & tabTitle
            else
                return ""
            end if
        end tell
        """

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                process.arguments = ["-e", script]

                let outputPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = Pipe()

                let timeoutItem = DispatchWorkItem { [weak process] in
                    if let p = process, p.isRunning {
                        p.terminate()
                    }
                }
                DispatchQueue.global().asyncAfter(deadline: .now() + 2.5, execute: timeoutItem)

                do {
                    try process.run()
                    let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    timeoutItem.cancel()

                    guard let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                          !output.isEmpty else {
                        continuation.resume(returning: nil)
                        return
                    }

                    let parts = output.components(separatedBy: "|||")
                    guard parts.count >= 4 else {
                        continuation.resume(returning: nil)
                        return
                    }

                    let winId = parts[0].trimmingCharacters(in: .whitespaces)
                    let tabId = parts[1].trimmingCharacters(in: .whitespaces)
                    let url = parts[2].trimmingCharacters(in: .whitespaces)
                    let title = parts.dropFirst(3).joined(separator: "|||").trimmingCharacters(in: .whitespaces)

                    // Filter out empty or chrome blank tabs
                    if url.isEmpty || url == "chrome://newtab/" || url == "about:blank" || url.hasPrefix("chrome://") {
                        continuation.resume(returning: nil)
                        return
                    }

                    let tabInfo = BrowserTabInfo(
                        windowId: winId,
                        tabId: tabId,
                        url: url,
                        title: title,
                        browserName: self.browserName
                    )
                    continuation.resume(returning: tabInfo)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
