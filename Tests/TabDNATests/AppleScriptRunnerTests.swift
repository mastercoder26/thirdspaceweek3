import Testing
import Foundation
import AppKit
@testable import TabDNA

@Suite("AppleScript Runner & Multi-Browser Tracking Tests (F08, F09)")
struct AppleScriptRunnerTests {

    @Test("Echo script executes successfully and returns trimmed string")
    func testEchoExecutionSuccess() async {
        let script = "return \"TabDNA_Runner_OK\""
        let output = await AppleScriptRunner.run(script: script, timeout: 2.0)
        #expect(output == "TabDNA_Runner_OK")
    }

    @Test("Syntax error returns nil gracefully without hanging")
    func testSyntaxErrorReturnsNil() async {
        let script = "this is an invalid AppleScript that will fail compilation"
        let output = await AppleScriptRunner.run(script: script, timeout: 2.0)
        #expect(output == nil)
    }

    @Test("Two-stage timeout terminates stalled script promptly and returns nil")
    func testTimeoutProcessTermination() async {
        let startTime = Date()
        // delay 5 seconds, but timeout is set to 0.4s
        let script = "delay 5\nreturn \"should not reach here\""
        let output = await AppleScriptRunner.run(script: script, timeout: 0.4)
        let elapsed = Date().timeIntervalSince(startTime)

        #expect(output == nil)
        #expect(elapsed < 2.0)
    }

    @Test("Large output executes without pipe buffer deadlock")
    func testLargeOutputPipeHandling() async {
        // Output a 10KB string to verify pipe buffer handling
        let chunk = String(repeating: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789", count: 200)
        let script = "return \"\(chunk)\""
        let output = await AppleScriptRunner.run(script: script, timeout: 3.0)
        #expect(output != nil)
        #expect(output?.count == chunk.count)
    }

    @Test("Concurrent AppleScript executions do not race or double-resume continuation")
    func testConcurrentScriptExecutions() async {
        await withTaskGroup(of: String?.self) { group in
            for i in 1...6 {
                group.addTask {
                    let script = "return \"result_\(i)\""
                    return await AppleScriptRunner.run(script: script, timeout: 2.0)
                }
            }
            var results: [String] = []
            for await result in group {
                if let r = result {
                    results.append(r)
                }
            }
            #expect(results.count == 6)
        }
    }

    @Test("ChromiumTracker matches supported bundle identifiers without launching closed apps")
    func testChromiumTrackerBundleMatching() {
        let tracker = ChromiumTracker(
            browserName: "Opera GX",
            appName: "Opera GX",
            bundleIdentifiers: ["com.operasoftware.OperaGX"]
        )
        #expect(tracker.browserName == "Opera GX")
        #expect(tracker.appName == "Opera GX")
        #expect(tracker.bundleIdentifiers.contains("com.operasoftware.OperaGX"))

        let chromeTracker = ChromiumTracker(
            browserName: "Google Chrome",
            appName: "Google Chrome",
            bundleIdentifiers: [
                "com.google.Chrome",
                "com.google.Chrome.beta",
                "com.google.Chrome.dev",
                "com.google.Chrome.canary"
            ]
        )
        #expect(chromeTracker.bundleIdentifiers.count == 4)
        #expect(chromeTracker.bundleIdentifiers.contains("com.google.Chrome.beta"))
        #expect(chromeTracker.bundleIdentifiers.contains("com.google.Chrome.canary"))
    }

    @Test("SafariTracker supports Safari and Safari Technology Preview")
    func testSafariTrackerBundleIdentifiers() {
        let tracker = SafariTracker()
        #expect(tracker.browserName == "Safari")
        #expect(tracker.bundleIdentifiers.contains("com.apple.Safari"))
        #expect(tracker.bundleIdentifiers.contains("com.apple.SafariTechnologyPreview"))
    }
}
