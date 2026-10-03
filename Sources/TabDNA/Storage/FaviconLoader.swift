import SwiftUI
import AppKit

@MainActor
public final class FaviconLoader: ObservableObject {
    public static let shared = FaviconLoader()

    private var memoryCache = NSCache<NSString, NSImage>()
    private var inFlightDomains: Set<String> = []
    private var failedDomains: Set<String> = []
    private let fileManager = FileManager.default
    private let cacheDir: URL

    private init() {
        let appSupport = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheDir = appSupport.appendingPathComponent("TabDNA_Favicons", isDirectory: true)
        try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    public func favicon(for domain: String) -> NSImage? {
        let clean = domain.lowercased()
        let key = clean as NSString
        if let cached = memoryCache.object(forKey: key) {
            return cached
        }

        let diskPath = cacheDir.appendingPathComponent("\(clean).png")
        if let diskData = try? Data(contentsOf: diskPath), let image = NSImage(data: diskData) {
            memoryCache.setObject(image, forKey: key)
            return image
        }

        if failedDomains.contains(clean) || inFlightDomains.contains(clean) {
            return nil
        }

        return nil
    }

    public func load(_ domain: String) async {
        let clean = domain.lowercased()
        guard UserDefaults.standard.bool(forKey: "TabDNA_LoadSiteIcons"),
              PrivacyManager.normalizedDomain(clean) != nil,
              memoryCache.object(forKey: clean as NSString) == nil,
              !failedDomains.contains(clean), !inFlightDomains.contains(clean) else { return }
        inFlightDomains.insert(clean)
        await fetchFaviconOnline(for: clean)
    }

    private func fetchFaviconOnline(for domain: String) async {
        let clean = domain.lowercased()
        defer {
            inFlightDomains.remove(clean)
        }
        guard !domain.isEmpty && domain != "web" && domain != "None" else {
            failedDomains.insert(clean)
            return
        }
        let urlString = "https://www.google.com/s2/favicons?domain=\(domain)&sz=64"
        guard let url = URL(string: urlString) else {
            failedDomains.insert(clean)
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                  let image = NSImage(data: data) else {
                failedDomains.insert(clean)
                return
            }

            let key = clean as NSString
            self.memoryCache.setObject(image, forKey: key)

            let diskPath = self.cacheDir.appendingPathComponent("\(clean).png")
            try? data.write(to: diskPath, options: .atomic)

            // Trigger object change so views update
            self.objectWillChange.send()
        } catch {
            failedDomains.insert(clean)
        }
    }
}

public struct FaviconView: View {
    @ObservedObject private var loader = FaviconLoader.shared
    @AppStorage("TabDNA_LoadSiteIcons") private var loadSiteIcons = false
    public let domain: String
    public let fallbackEmoji: String
    public let size: CGFloat

    public init(domain: String, fallbackEmoji: String, size: CGFloat = 22) {
        self.domain = domain
        self.fallbackEmoji = fallbackEmoji
        self.size = size
    }

    public var body: some View {
        Group {
            if let image = loader.favicon(for: domain) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Image(systemName: "globe")
                    .font(.system(size: size * 0.75))
                    .foregroundStyle(.secondary)
                    .frame(width: size, height: size)
            }
        }
        .task(id: domain + String(loadSiteIcons)) { await loader.load(domain) }
    }
}
