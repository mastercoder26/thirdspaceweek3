import Foundation

protocol SessionClassifierProtocol: Sendable {
    func analyzeSession(nodes: [BrowsingNode]) async -> (title: String, category: SessionCategory)
}

// Uses only recorded titles and domains. Names describe a real page in the session.
struct SessionClassifier: SessionClassifierProtocol {
    func analyzeSession(nodes: [BrowsingNode]) async -> (title: String, category: SessionCategory) {
        let chronologicalNodes = nodes.sorted { $0.timestampOpened < $1.timestampOpened }
        guard let firstPage = chronologicalNodes.first else { return ("Browsing session", .general) }

        let categories = chronologicalNodes.map(category(for:))
        return (String(firstPage.title.prefix(100)), dominantCategory(in: categories))
    }

    private func dominantCategory(in categories: [SessionCategory]) -> SessionCategory {
        let categoryOrder: [SessionCategory] = [
            .coding, .homework, .research, .news, .shopping, .entertainment,
        ]
        // Unclassified pages shouldn't outweigh a recognizable topic.
        let counts = Dictionary(grouping: categories.filter { $0 != .general }, by: { $0 })
            .mapValues { $0.count }
        let suggestion = categoryOrder.max { (counts[$0] ?? 0) < (counts[$1] ?? 0) } ?? .general
        return (counts[suggestion] ?? 0) > 0 ? suggestion : .general
    }

    private func category(for node: BrowsingNode) -> SessionCategory {
        let domain = node.domain.lowercased()
        let words = Set(node.title.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init))
        func matchesSite(_ hosts: [String]) -> Bool {
            hosts.contains { domain == $0 || domain.hasSuffix("." + $0) }
        }
        func mentions(_ tokens: [String]) -> Bool {
            !words.isDisjoint(with: tokens)
        }

        if matchesSite([
            "github.com", "gitlab.com", "stackoverflow.com", "developer.apple.com", "developer.mozilla.org",
            "docs.swift.org",
        ]) || mentions(["swiftui", "python", "rust", "programming", "documentation", "api"]) {
            return .coding
        }
        if matchesSite(["instructure.com", "blackboard.com"])
            || mentions(["homework", "syllabus", "coursework", "quiz"])
        {
            return .homework
        }
        if matchesSite(["wikipedia.org", "scholar.google.com", "pubmed.ncbi.nlm.nih.gov", "arxiv.org"])
            || mentions(["research", "study", "history"])
        {
            return .research
        }
        if matchesSite([
            "nytimes.com", "wsj.com", "bbc.com", "bbc.co.uk", "reuters.com", "apnews.com", "theverge.com",
        ]) || mentions(["news"]) {
            return .news
        }
        if matchesSite(["amazon.com", "ebay.com", "etsy.com"]) || mentions(["checkout", "shopping", "cart"]) {
            return .shopping
        }
        if matchesSite(["youtube.com", "netflix.com", "spotify.com", "reddit.com", "vimeo.com"]) {
            return .entertainment
        }
        return .general
    }
}
