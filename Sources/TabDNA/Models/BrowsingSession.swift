import Foundation
import SwiftUI

public enum SessionCategory: String, Codable, CaseIterable, Sendable {
    case research = "Research"
    case coding = "Coding & Tech"
    case homework = "Academic & School"
    case news = "News & Media"
    case shopping = "Shopping"
    case entertainment = "Entertainment"
    case rabbitHole = "Deep Rabbit Hole"
    case general = "General"

    public var displayName: String { self == .rabbitHole ? "Extended browsing" : rawValue }

    public var icon: String {
        switch self {
        case .research: return "magnifyingglass.circle.fill"
        case .coding: return "curlybraces.square.fill"
        case .homework: return "graduationcap.fill"
        case .news: return "newspaper.fill"
        case .shopping: return "cart.fill"
        case .entertainment: return "play.tv.fill"
        case .rabbitHole: return "point.forward.to.point.capsulepath.fill"
        case .general: return "safari.fill"
        }
    }

    public var color: Color {
        switch self {
        case .research: return .purple
        case .coding: return .cyan
        case .homework: return .blue
        case .news: return .orange
        case .shopping: return .green
        case .entertainment: return .pink
        case .rabbitHole: return .indigo
        case .general: return .gray
        }
    }
}

public struct DomainVisitCount: Codable, Hashable, Sendable {
    public let domain: String
    public var visitCount: Int
    public var activeDurationSeconds: TimeInterval

    public init(domain: String, visitCount: Int = 1, activeDurationSeconds: TimeInterval = 0) {
        self.domain = domain
        self.visitCount = visitCount
        self.activeDurationSeconds = activeDurationSeconds
    }
}

public struct BrowsingSession: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var aiTitle: String?
    public var customTitle: String?
    public var category: SessionCategory
    public var startTime: Date
    public var endTime: Date?
    public var totalActiveDuration: TimeInterval
    public var pageCount: Int
    public var branchCount: Int
    public var maxDepth: Int
    public var mainDomains: [DomainVisitCount]
    public var isActive: Bool
    public var aiSummary: String?

    public init(
        id: UUID = UUID(),
        title: String = "Browsing Session",
        aiTitle: String? = nil,
        customTitle: String? = nil,
        category: SessionCategory = .general,
        startTime: Date = Date(),
        endTime: Date? = nil,
        totalActiveDuration: TimeInterval = 0,
        pageCount: Int = 0,
        branchCount: Int = 0,
        maxDepth: Int = 0,
        mainDomains: [DomainVisitCount] = [],
        isActive: Bool = true,
        aiSummary: String? = nil
    ) {
        self.id = id
        self.title = title
        self.aiTitle = aiTitle
        self.customTitle = customTitle
        self.category = category
        self.startTime = startTime
        self.endTime = endTime
        self.totalActiveDuration = totalActiveDuration
        self.pageCount = pageCount
        self.branchCount = branchCount
        self.maxDepth = maxDepth
        self.mainDomains = mainDomains
        self.isActive = isActive
        self.aiSummary = aiSummary
    }

    public var displayTitle: String {
        if let customTitle, !customTitle.isEmpty { return customTitle }
        if let ai = aiTitle, !ai.isEmpty {
            return ai
        }
        return title
    }

    public var formattedDuration: String {
        let seconds = Int(totalActiveDuration)
        if seconds < 60 {
            return "\(max(0, seconds))s"
        }
        let minutes = seconds / 60
        let remSeconds = seconds % 60
        if minutes < 60 {
            return remSeconds > 0 ? "\(minutes)m \(remSeconds)s" : "\(minutes)m"
        }
        let hours = minutes / 60
        let remMinutes = minutes % 60
        return "\(hours)h \(remMinutes)m"
    }

    public var formattedTimeRange: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let start = formatter.string(from: startTime)
        if let end = endTime {
            let endStr = formatter.string(from: end)
            return "\(start) – \(endStr)"
        } else {
            return isActive ? "\(start) – Now" : start
        }
    }

    public var topDomain: String {
        mainDomains.sorted { $0.visitCount > $1.visitCount }.first?.domain ?? "web"
    }
}
