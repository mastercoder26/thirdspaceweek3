import Foundation

public final class PrivacyManager: @unchecked Sendable {
    public static let shared = PrivacyManager()

    private let defaultsKey = "TabDNA_BlacklistedDomains"
    private let auditCountKey = "TabDNA_PrivacyFilteredCount"
    private let lock = NSLock()

    private var blacklistedDomains: Set<String>
    private(set) var filteredCount: Int

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.stringArray(forKey: defaultsKey)
        if let stored = stored {
            self.blacklistedDomains = Set(stored.map { $0.lowercased() })
        } else {
            self.blacklistedDomains = [
                "chase.com",
                "bankofamerica.com",
                "wellsfargo.com",
                "paypal.com",
                "accounts.google.com",
                "login.microsoftonline.com",
                "appleid.apple.com",
                "1password.com",
                "bitwarden.com",
                "lastpass.com",
                "mint.intuit.com"
            ]
        }
        self.filteredCount = defaults.integer(forKey: auditCountKey)
    }

    public func isDomainBlacklisted(_ domain: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let clean = domain.lowercased()
        for blacklisted in blacklistedDomains {
            if clean == blacklisted || clean.hasSuffix("." + blacklisted) {
                return true
            }
        }
        return false
    }

    public func shouldRecord(url: String, domain: String) -> Bool {
        if isDomainBlacklisted(domain) {
            recordFilteredEvent()
            return false
        }

        let lower = url.lowercased()
        if lower.contains("login") || lower.contains("signin") || lower.contains("password") || lower.contains("checkout") {
            // Check if domain is specifically privacy-sensitive
            if lower.contains("auth") || lower.contains("sso") {
                recordFilteredEvent()
                return false
            }
        }
        return true
    }

    public func sanitize(url: String) -> String {
        guard var components = URLComponents(string: url) else { return url }
        if let items = components.queryItems {
            let sensitiveKeys: Set<String> = ["token", "auth", "access_token", "key", "password", "pwd", "secret", "code", "session", "user_id"]
            components.queryItems = items.filter { !sensitiveKeys.contains($0.name.lowercased()) }
        }
        return components.string ?? url
    }

    private func recordFilteredEvent() {
        lock.lock()
        filteredCount += 1
        defaults.set(filteredCount, forKey: auditCountKey)
        lock.unlock()
    }

    public func getBlacklist() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(blacklistedDomains).sorted()
    }

    public static func normalizedDomain(_ input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty, !trimmed.contains(where: { $0.isWhitespace }) else { return nil }
        let candidate = trimmed.contains("://") ? trimmed : "https://" + trimmed
        guard let url = URLComponents(string: candidate), let host = url.host,
              url.user == nil, url.password == nil,
              host.contains("."), !host.hasPrefix("."), !host.hasSuffix("."),
              host.split(separator: ".", omittingEmptySubsequences: false).allSatisfy({ !$0.isEmpty && !$0.hasPrefix("-") && !$0.hasSuffix("-") && $0.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" } }) else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    public func addDomain(_ domain: String) {
        guard let clean = Self.normalizedDomain(domain) else { return }
        lock.lock()
        blacklistedDomains.insert(clean)
        defaults.set(Array(blacklistedDomains), forKey: defaultsKey)
        lock.unlock()
    }

    public func removeDomain(_ domain: String) {
        lock.lock()
        blacklistedDomains.remove(domain.lowercased())
        defaults.set(Array(blacklistedDomains), forKey: defaultsKey)
        lock.unlock()
    }

    public func resetToDefaults() {
        lock.lock()
        blacklistedDomains = [
            "chase.com",
            "bankofamerica.com",
            "wellsfargo.com",
            "paypal.com",
            "accounts.google.com",
            "login.microsoftonline.com",
            "appleid.apple.com",
            "1password.com",
            "bitwarden.com",
            "lastpass.com",
            "mint.intuit.com"
        ]
        defaults.set(Array(blacklistedDomains), forKey: defaultsKey)
        lock.unlock()
    }
}
