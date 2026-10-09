import AppKit
import Combine
import CoreGraphics
import Foundation

@MainActor
public final class BrowserObserver: ObservableObject {
    public static let shared = BrowserObserver()

    @Published public private(set) var isTrackingEnabled: Bool = true
    @Published public private(set) var activeBrowserName: String = "Waiting for a browser"
    @Published public private(set) var currentTabInfo: BrowserTabInfo? = nil
    @Published public private(set) var lastActiveNodeId: UUID? = nil

    private var trackers: [BrowserTrackerProtocol] = []
    private var timer: Timer?
    private var isPolling = false
    private var trackingGeneration = 0
    private var workspaceObserver: NSObjectProtocol?

    private var visitResolver = BrowserVisitResolver()
    private var lastPollTime: Date = Date()
    private var lastActivityTime: Date = Date()

    public var pollingInterval: TimeInterval = 2.0 {
        didSet { if isTrackingEnabled && timer != nil { startTracking() } }
    }
    public var inactivityThreshold: TimeInterval = 25 * 60  // 25 minutes
    public var idleThreshold: TimeInterval = 60.0  // 60 seconds of no input = idle away from Mac

    /// Provider for system idle time (seconds since last keyboard/mouse event).
    /// Tests supply a clock here instead of depending on live keyboard and mouse input.
    public var idleTimeProvider: @Sendable () -> TimeInterval = {
        let idle = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
        return idle >= 0 ? idle : 0
    }

    public var onNewNodeRecorded: (@MainActor (BrowsingNode) -> Void)?
    public var onNodeDurationUpdated: (@MainActor (UUID, TimeInterval) -> Void)?
    public var onNodeTitleUpdated: (@MainActor (UUID, String) -> Void)?
    public var onInactivitySessionBoundary: (@MainActor () -> Void)?

    private init() {
        let defaults = UserDefaults.standard
        pollingInterval = defaults.object(forKey: "TabDNA_PollingInterval") as? Double ?? 2
        inactivityThreshold = (defaults.object(forKey: "TabDNA_InactivityMinutes") as? Double ?? 25) * 60
        isTrackingEnabled =
            defaults.object(forKey: "TabDNA_TrackingEnabled") as? Bool ?? !RuntimeConfiguration.isUITest
        if !isTrackingEnabled { activeBrowserName = "Resume when you’re ready" }
        if !RuntimeConfiguration.isUITest { setupTrackers() }
    }

    deinit {
        if let obs = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
        }
    }

    private func setupTrackers() {
        trackers = [
            SafariTracker(),
            ChromiumTracker(
                browserName: "Google Chrome",
                appName: "Google Chrome",
                bundleIdentifiers: [
                    "com.google.Chrome",
                    "com.google.Chrome.beta",
                    "com.google.Chrome.dev",
                    "com.google.Chrome.canary",
                ]
            ),
            ChromiumTracker(
                browserName: "Brave",
                appName: "Brave Browser",
                bundleIdentifiers: [
                    "com.brave.Browser",
                    "com.brave.Browser.beta",
                    "com.brave.Browser.nightly",
                ]
            ),
            ChromiumTracker(
                browserName: "Arc",
                appName: "Arc",
                bundleIdentifiers: [
                    "company.thebrowser.Browser"
                ]
            ),
            ChromiumTracker(
                browserName: "Microsoft Edge",
                appName: "Microsoft Edge",
                bundleIdentifiers: [
                    "com.microsoft.edgemac",
                    "com.microsoft.edgemac.Beta",
                    "com.microsoft.edgemac.Dev",
                    "com.microsoft.edgemac.Canary",
                ]
            ),
            ChromiumTracker(
                browserName: "Opera GX",
                appName: "Opera GX",
                bundleIdentifiers: [
                    "com.operasoftware.OperaGX"
                ]
            ),
            ChromiumTracker(
                browserName: "Opera",
                appName: "Opera",
                bundleIdentifiers: [
                    "com.operasoftware.Opera",
                    "com.operasoftware.OperaNext",
                    "com.operasoftware.OperaDeveloper",
                ]
            ),
            ChromiumTracker(
                browserName: "Vivaldi",
                appName: "Vivaldi",
                bundleIdentifiers: [
                    "com.vivaldi.Vivaldi",
                    "com.vivaldi.Vivaldi.snapshot",
                ]
            ),
            ChromiumTracker(
                browserName: "Chromium",
                appName: "Chromium",
                bundleIdentifiers: [
                    "org.chromium.Chromium"
                ]
            ),
            ChromiumTracker(
                browserName: "Comet",
                appName: "Comet",
                bundleIdentifiers: [
                    "ai.perplexity.comet"
                ]
            ),
        ]
    }

    public func setTrackersForTesting(_ customTrackers: [BrowserTrackerProtocol]) {
        self.trackers = customTrackers
    }

    public func processTabInfoForTesting(_ tabInfo: BrowserTabInfo) {
        processTabInfo(tabInfo)
    }

    public func startTracking() {
        isTrackingEnabled = true
        UserDefaults.standard.set(true, forKey: "TabDNA_TrackingEnabled")
        trackingGeneration += 1
        activeBrowserName = "Waiting for a browser"
        timer?.invalidate()
        lastPollTime = Date()

        if workspaceObserver == nil {
            workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    await self?.pollActiveBrowser()
                }
            }
        }

        timer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.pollActiveBrowser()
            }
        }
    }

    public func pauseTracking() {
        isTrackingEnabled = false
        UserDefaults.standard.set(false, forKey: "TabDNA_TrackingEnabled")
        trackingGeneration += 1
        activeBrowserName = "Resume when you’re ready"
        timer?.invalidate()
        timer = nil
        if let obs = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
            workspaceObserver = nil
        }
        currentTabInfo = nil
        lastActiveNodeId = nil
        visitResolver.clearActivePage()
    }

    public func toggleTracking() {
        if isTrackingEnabled {
            pauseTracking()
        } else {
            startTracking()
        }
    }

    public func resetSessionTrackingState() {
        visitResolver.reset()
        lastActiveNodeId = nil
        lastActivityTime = Date()
        lastPollTime = Date()
        currentTabInfo = nil
    }

    private func pollActiveBrowser() async {
        guard isTrackingEnabled else { return }

        guard !isPolling else { return }
        isPolling = true
        defer { isPolling = false }
        let generation = trackingGeneration
        guard let tracker = trackers.first(where: { $0.isFrontmost() }) else {
            activeBrowserName = "Waiting for a browser"
            currentTabInfo = nil
            lastActiveNodeId = nil
            visitResolver.clearActivePage()
            lastPollTime = Date()
            return
        }
        activeBrowserName = tracker.browserName
        guard let tabInfo = await tracker.fetchActiveTab(),
            isTrackingEnabled, generation == trackingGeneration, tracker.isFrontmost()
        else {
            // An empty tab can be a page loading. Keep its connection and browser status until the next poll.
            return
        }
        processTabInfo(tabInfo)
    }

    private func isPlaceholderTitle(_ title: String, domain: String, url: String) -> Bool {
        let lower = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lower.isEmpty { return true }
        if lower == "loading..." || lower == "loading" || lower == "untitled" || lower == "web page" {
            return true
        }
        if lower == domain.lowercased() || lower == "www." + domain.lowercased() { return true }
        if lower == url.lowercased() { return true }
        return false
    }

    private func processTabInfo(_ tabInfo: BrowserTabInfo) {
        let now = Date()
        guard let scheme = URL(string: tabInfo.url)?.scheme?.lowercased(), ["http", "https"].contains(scheme)
        else {
            currentTabInfo = nil
            lastActiveNodeId = nil
            visitResolver.clearActivePage()
            lastPollTime = now
            return
        }
        let sanitizedUrl = PrivacyManager.shared.sanitize(url: tabInfo.url)
        let domain = BrowsingNode.extractDomain(from: sanitizedUrl)

        guard PrivacyManager.shared.shouldRecord(url: sanitizedUrl, domain: domain) else {
            currentTabInfo = nil
            activeBrowserName = "Excluded by privacy settings"
            lastActiveNodeId = nil
            visitResolver.clearActivePage()
            lastPollTime = now
            return
        }

        let previousPoll = lastPollTime
        lastPollTime = now
        let delta = max(0, min(now.timeIntervalSince(previousPoll), 15.0))

        let systemIdle = idleTimeProvider()
        let isIdle = systemIdle >= idleThreshold

        // Idle polls must not postpone the next session boundary.
        if !isIdle {
            lastActivityTime = now
        }

        let idleGap = max(systemIdle, now.timeIntervalSince(lastActivityTime))
        if idleGap > inactivityThreshold && !SessionManager.shared.currentSessionNodes.isEmpty {
            onInactivitySessionBoundary?()
            resetSessionTrackingState()
            if isIdle { return }
        }

        if SessionManager.shared.currentSession?.isActive != true {
            _ = SessionManager.shared.startNewSession()
        }

        let sessionId = SessionManager.shared.currentSessionId
        let resolution = visitResolver.resolve(
            tab: tabInfo, url: sanitizedUrl, sessionId: sessionId,
            lookup: { HistoryStore.shared.getNode(id: $0) })
        if let existing = resolution.existing {
            // Browsers may publish the URL before the final page title.
            let cleanTitle = tabInfo.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanTitle.isEmpty && cleanTitle != existing.title
                && !isPlaceholderTitle(cleanTitle, domain: existing.domain, url: existing.url)
                && isPlaceholderTitle(existing.title, domain: existing.domain, url: existing.url)
            {
                HistoryStore.shared.updateNodeTitle(nodeId: existing.id, title: cleanTitle)
                onNodeTitleUpdated?(existing.id, cleanTitle)
            }

            // A visible page is not active browsing time while the user is away.
            if lastActiveNodeId == existing.id && !isIdle {
                HistoryStore.shared.updateNodeDuration(
                    nodeId: existing.id, durationDelta: delta, lastActive: now)
                onNodeDurationUpdated?(existing.id, delta)
            }
            visitResolver.record(existing, tab: tabInfo)
            lastActiveNodeId = existing.id
            currentTabInfo = tabInfo
            return
        }
        let parentNodeId = resolution.parent?.id
        let branchLevel = resolution.parent.map { $0.branchLevel + 1 } ?? 0

        let currentSessionId = SessionManager.shared.currentSessionId
        let newNode = BrowsingNode(
            sessionId: currentSessionId,
            url: sanitizedUrl,
            title: tabInfo.title,
            domain: domain,
            timestampOpened: now,
            timestampLastActive: now,
            activeDurationSeconds: 0,
            windowId: tabInfo.windowId,
            tabId: tabInfo.tabId,
            parentNodeId: parentNodeId,
            branchLevel: branchLevel,
            orderIndex: HistoryStore.shared.getNodes(for: currentSessionId).count,
            browserName: tabInfo.browserName
        )

        visitResolver.record(newNode, tab: tabInfo)
        lastActiveNodeId = newNode.id

        HistoryStore.shared.saveNode(newNode)
        onNewNodeRecorded?(newNode)
        self.currentTabInfo = tabInfo
    }
}
