import Foundation

public struct BrowsingNode: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var sessionId: UUID
    public var url: String
    public var title: String
    public var domain: String
    public var faviconEmoji: String
    public var timestampOpened: Date
    public var timestampLastActive: Date
    public var activeDurationSeconds: TimeInterval
    public var windowId: String
    public var tabId: String
    public var parentNodeId: UUID?
    public var branchLevel: Int
    public var orderIndex: Int
    public var browserName: String
    public var notes: String?
    public var isPinned: Bool
    public var tags: [String]

    public init(
        id: UUID = UUID(),
        sessionId: UUID,
        url: String,
        title: String,
        domain: String? = nil,
        faviconEmoji: String? = nil,
        timestampOpened: Date = Date(),
        timestampLastActive: Date = Date(),
        activeDurationSeconds: TimeInterval = 0,
        windowId: String = "1",
        tabId: String = "1",
        parentNodeId: UUID? = nil,
        branchLevel: Int = 0,
        orderIndex: Int = 0,
        browserName: String = "Comet",
        notes: String? = nil,
        isPinned: Bool = false,
        tags: [String] = []
    ) {
        self.id = id
        self.sessionId = sessionId
        self.url = url
        self.title = title.isEmpty ? (domain ?? "Web Page") : title
        let extractedDomain = domain ?? BrowsingNode.extractDomain(from: url)
        self.domain = extractedDomain
        self.faviconEmoji = faviconEmoji ?? BrowsingNode.suggestEmoji(for: extractedDomain, title: title)
        self.timestampOpened = timestampOpened
        self.timestampLastActive = timestampLastActive
        self.activeDurationSeconds = activeDurationSeconds
        self.windowId = windowId
        self.tabId = tabId
        self.parentNodeId = parentNodeId
        self.branchLevel = branchLevel
        self.orderIndex = orderIndex
        self.browserName = browserName
        self.notes = notes
        self.isPinned = isPinned
        self.tags = tags
    }

    enum CodingKeys: String, CodingKey {
        case id, sessionId, url, title, domain, faviconEmoji
        case timestampOpened, timestampLastActive, activeDurationSeconds
        case windowId, tabId, parentNodeId, branchLevel, orderIndex
        case browserName, notes, isPinned, tags
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.sessionId = try container.decode(UUID.self, forKey: .sessionId)
        self.url = try container.decode(String.self, forKey: .url)
        let decodedTitle = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.title = decodedTitle.isEmpty ? "Web Page" : decodedTitle
        let extractedDomain = try container.decodeIfPresent(String.self, forKey: .domain) ?? BrowsingNode.extractDomain(from: self.url)
        self.domain = extractedDomain
        self.faviconEmoji = try container.decodeIfPresent(String.self, forKey: .faviconEmoji) ?? BrowsingNode.suggestEmoji(for: extractedDomain, title: self.title)
        self.timestampOpened = try container.decodeIfPresent(Date.self, forKey: .timestampOpened) ?? Date()
        self.timestampLastActive = try container.decodeIfPresent(Date.self, forKey: .timestampLastActive) ?? self.timestampOpened
        self.activeDurationSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .activeDurationSeconds) ?? 0
        self.windowId = try container.decodeIfPresent(String.self, forKey: .windowId) ?? "1"
        self.tabId = try container.decodeIfPresent(String.self, forKey: .tabId) ?? "1"
        self.parentNodeId = try container.decodeIfPresent(UUID.self, forKey: .parentNodeId)
        self.branchLevel = try container.decodeIfPresent(Int.self, forKey: .branchLevel) ?? 0
        self.orderIndex = try container.decodeIfPresent(Int.self, forKey: .orderIndex) ?? 0
        self.browserName = try container.decodeIfPresent(String.self, forKey: .browserName) ?? "Comet"
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes)
        self.isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        self.tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
    }

    public var formattedDuration: String {
        let totalSeconds = Int(activeDurationSeconds)
        if totalSeconds < 60 {
            return "\(max(0, totalSeconds))s"
        }
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        if minutes < 60 {
            return seconds > 0 ? "\(minutes)m \(seconds)s" : "\(minutes)m"
        }
        let hours = minutes / 60
        let remMinutes = minutes % 60
        return "\(hours)h \(remMinutes)m"
    }

    public var reopenURL: URL? {
        guard let url = URL(string: url), ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else { return nil }
        return url
    }

    public func matches(_ query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty || title.localizedCaseInsensitiveContains(query) ||
            domain.localizedCaseInsensitiveContains(query) || url.localizedCaseInsensitiveContains(query) ||
            (notes ?? "").localizedCaseInsensitiveContains(query)
    }

    public var hasNotes: Bool { !(notes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) }

    public var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestampOpened)
    }

    public static func extractDomain(from urlString: String) -> String {
        guard let url = URL(string: urlString), let host = url.host else {
            return "web"
        }
        var clean = host.lowercased()
        if clean.hasPrefix("www.") {
            clean = String(clean.dropFirst(4))
        }
        return clean
    }

    public static func suggestEmoji(for domain: String, title: String) -> String {
        let lower = (domain + " " + title).lowercased()

        if lower.contains("wikipedia") { return "📖" }
        if lower.contains("google") { return "🔍" }
        if lower.contains("chatgpt") || lower.contains("openai") { return "🤖" }
        if lower.contains("perplexity") || lower.contains("comet") { return "💫" }
        if lower.contains("github") || lower.contains("gitlab") { return "💻" }
        if lower.contains("youtube") || lower.contains("vimeo") { return "▶️" }
        if lower.contains("reddit") { return "💬" }
        if lower.contains("stackoverflow") { return "📚" }
        if lower.contains("apollo") || lower.contains("nasa") || lower.contains("space") { return "🚀" }
        if lower.contains("war") || lower.contains("crisis") || lower.contains("history") { return "🏛️" }
        if lower.contains("news") || lower.contains("times") || lower.contains("post") { return "📰" }
        if lower.contains("amazon") || lower.contains("ebay") || lower.contains("shop") { return "🛍️" }
        if lower.contains("twitter") || lower.contains("x.com") { return "🐦" }
        if lower.contains("medium") || lower.contains("substack") { return "✍️" }
        if lower.contains("apple") { return "🍏" }
        if lower.contains("docs") || lower.contains("notion") { return "📝" }

        return "🌐"
    }
}
