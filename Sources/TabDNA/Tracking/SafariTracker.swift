import Foundation
import AppKit

public final class SafariTracker: BrowserTrackerProtocol, @unchecked Sendable {
    public let browserName: String = "Safari"
    public let bundleIdentifiers: [String] = ["com.apple.Safari"]

    public init() {}

    public func isRunning() -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        return runningApps.contains { $0.bundleIdentifier == "com.apple.Safari" }
    }

    public func isFrontmost() -> Bool {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return false }
        return frontApp.bundleIdentifier == "com.apple.Safari"
    }

    public func fetchActiveTab() async -> BrowserTabInfo? {
        guard isRunning() else { return nil }

        let script = """
        tell application "Safari"
            if (count of windows) > 0 then
                set frontWin to front window
                set winId to id of frontWin as text
                set curTab to current tab of frontWin
                set tabId to (index of curTab as text)
                set tabUrl to URL of curTab
                set tabTitle to name of curTab
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

                    if url.isEmpty || url == "favorites://" || url.hasPrefix("safari-resource://") {
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
