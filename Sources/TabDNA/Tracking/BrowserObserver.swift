import Foundation
import AppKit
import Combine

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

    // Tracking state
    private var visitResolver = BrowserVisitResolver()
    private var lastPollTime: Date = Date()
    private var lastActivityTime: Date = Date()

    public var pollingInterval: TimeInterval = 2.0 {
        didSet { if isTrackingEnabled && timer != nil { startTracking() } }
    }
    public var inactivityThreshold: TimeInterval = 25 * 60 // 25 minutes

    // Callback closures for loose coupling
    public var onNewNodeRecorded: (@MainActor (BrowsingNode) -> Void)?
    public var onNodeDurationUpdated: (@MainActor (UUID, TimeInterval) -> Void)?
    public var onInactivitySessionBoundary: (@MainActor () -> Void)?

    private init() {
        let defaults = UserDefaults.standard
        pollingInterval = defaults.object(forKey: "TabDNA_PollingInterval") as? Double ?? 2
        inactivityThreshold = (defaults.object(forKey: "TabDNA_InactivityMinutes") as? Double ?? 25) * 60
        isTrackingEnabled = defaults.object(forKey: "TabDNA_TrackingEnabled") as? Bool ?? !RuntimeConfiguration.isUITest
        if !isTrackingEnabled { activeBrowserName = "Resume when you’re ready" }
        if !RuntimeConfiguration.isUITest { setupTrackers() }
    }

    private func setupTrackers() {
        trackers = [
            ChromiumTracker(browserName: "Comet", appName: "Comet", bundleIdentifiers: ["ai.perplexity.comet"]),
            ChromiumTracker(browserName: "Google Chrome", appName: "Google Chrome", bundleIdentifiers: ["com.google.Chrome"]),
            ChromiumTracker(browserName: "Brave", appName: "Brave Browser", bundleIdentifiers: ["com.brave.Browser"]),
            ChromiumTracker(browserName: "Arc", appName: "Arc", bundleIdentifiers: ["company.thebrowser.Browser"]),
            ChromiumTracker(browserName: "Microsoft Edge", appName: "Microsoft Edge", bundleIdentifiers: ["com.microsoft.edgemac"]),
            ChromiumTracker(browserName: "Opera", appName: "Opera", bundleIdentifiers: ["com.operasoftware.Opera"]),
            ChromiumTracker(browserName: "Vivaldi", appName: "Vivaldi", bundleIdentifiers: ["com.vivaldi.Vivaldi"]),
            ChromiumTracker(browserName: "Chromium", appName: "Chromium", bundleIdentifiers: ["org.chromium.Chromium"]),
            SafariTracker()
        ]
    }

    public func startTracking() {
        isTrackingEnabled = true
        UserDefaults.standard.set(true, forKey: "TabDNA_TrackingEnabled")
        trackingGeneration += 1
        activeBrowserName = "Waiting for a browser"
        timer?.invalidate()
        lastPollTime = Date()
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
              isTrackingEnabled, generation == trackingGeneration, tracker.isFrontmost() else {
            if isTrackingEnabled && generation == trackingGeneration {
                currentTabInfo = nil
                activeBrowserName = "Browser access unavailable"
                lastActiveNodeId = nil
                visitResolver.clearActivePage()
                lastPollTime = Date()
            }
            return
        }
        processTabInfo(tabInfo)
    }

    private func processTabInfo(_ tabInfo: BrowserTabInfo) {
        let now = Date()
        guard let scheme = URL(string: tabInfo.url)?.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
            currentTabInfo = nil
            lastActiveNodeId = nil
            visitResolver.clearActivePage()
            lastPollTime = now
            return
        }
        let sanitizedUrl = PrivacyManager.shared.sanitize(url: tabInfo.url)
        let domain = BrowsingNode.extractDomain(from: sanitizedUrl)

        // Check privacy filter
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

        // Check inactivity threshold
        let idleGap = now.timeIntervalSince(lastActivityTime)
        if idleGap > inactivityThreshold && !SessionManager.shared.currentSessionNodes.isEmpty {
            onInactivitySessionBoundary?()
            resetSessionTrackingState()
        }
        lastActivityTime = now

        if SessionManager.shared.currentSession?.isActive != true {
            _ = SessionManager.shared.startNewSession()
        }

        let sessionId = SessionManager.shared.currentSessionId
        let resolution = visitResolver.resolve(tab: tabInfo, url: sanitizedUrl, sessionId: sessionId,
            lookup: { HistoryStore.shared.getNode(id: $0) })
        if let existing = resolution.existing {
            if lastActiveNodeId == existing.id {
                HistoryStore.shared.updateNodeDuration(nodeId: existing.id, durationDelta: delta, lastActive: now)
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

        // Persist and notify
        HistoryStore.shared.saveNode(newNode)
        onNewNodeRecorded?(newNode)
        self.currentTabInfo = tabInfo
    }
}
