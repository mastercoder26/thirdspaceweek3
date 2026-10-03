import Foundation

protocol SessionClassifierProtocol: Sendable {
    func analyzeSession(nodes: [BrowsingNode]) async -> (title: String, category: SessionCategory)
}

// Uses only recorded titles and domains. Names describe a real page in the session.
struct SessionClassifier: SessionClassifierProtocol {
    func analyzeSession(nodes: [BrowsingNode]) async -> (title: String, category: SessionCategory) {
        let ordered = nodes.sorted { $0.timestampOpened < $1.timestampOpened }
        guard let first = ordered.first else { return ("Browsing session", .general) }
        let categories = ordered.map(category(for:))
        let priority: [SessionCategory] = [.coding, .homework, .research, .news, .shopping, .entertainment]
        let counts = Dictionary(grouping: categories.filter { $0 != .general }, by: { $0 }).mapValues { $0.count }
        let suggested = priority.max { (counts[$0] ?? 0) < (counts[$1] ?? 0) } ?? .general
        let category: SessionCategory = (counts[suggested] ?? 0) > 0 ? suggested : .general
        return (String(first.title.prefix(100)), category)
    }

    private func category(for node: BrowsingNode) -> SessionCategory {
        let domain = node.domain.lowercased()
        let words = Set(node.title.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init))
        func site(_ hosts: [String]) -> Bool {
            hosts.contains { domain == $0 || domain.hasSuffix("." + $0) }
        }
        func mentions(_ tokens: [String]) -> Bool { !words.isDisjoint(with: tokens) }
        if site(["github.com", "gitlab.com", "stackoverflow.com", "developer.apple.com", "developer.mozilla.org", "docs.swift.org"]) || mentions(["swiftui", "python", "rust", "programming", "documentation", "api"]) { return .coding }
        if site(["instructure.com", "blackboard.com"]) || mentions(["homework", "syllabus", "coursework", "quiz"]) { return .homework }
        if site(["wikipedia.org", "scholar.google.com", "pubmed.ncbi.nlm.nih.gov", "arxiv.org"]) || mentions(["research", "study", "history"]) { return .research }
        if site(["nytimes.com", "wsj.com", "bbc.com", "bbc.co.uk", "reuters.com", "apnews.com", "theverge.com"]) || mentions(["news"]) { return .news }
        if site(["amazon.com", "ebay.com", "etsy.com"]) || mentions(["checkout", "shopping", "cart"]) { return .shopping }
        if site(["youtube.com", "netflix.com", "spotify.com", "reddit.com", "vimeo.com"]) { return .entertainment }
        return .general
    }
}
