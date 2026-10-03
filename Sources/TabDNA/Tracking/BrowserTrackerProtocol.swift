import Foundation
import AppKit

public struct BrowserTabInfo: Sendable, Equatable {
    public let windowId: String
    public let tabId: String
    public let url: String
    public let title: String
    public let browserName: String
    public let timestamp: Date

    public init(
        windowId: String,
        tabId: String,
        url: String,
        title: String,
        browserName: String,
        timestamp: Date = Date()
    ) {
        self.windowId = windowId
        self.tabId = tabId
        self.url = url
        self.title = title
        self.browserName = browserName
        self.timestamp = timestamp
    }
}

public protocol BrowserTrackerProtocol: Sendable {
    var browserName: String { get }
    var bundleIdentifiers: [String] { get }
    func isRunning() -> Bool
    func isFrontmost() -> Bool
    func fetchActiveTab() async -> BrowserTabInfo?
}
