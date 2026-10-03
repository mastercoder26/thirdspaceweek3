import SwiftUI
import AppKit

enum SavedPageFilter: String, CaseIterable, Identifiable {
    case all = "All saved"
    case starred = "Starred"
    case notes = "With notes"
    var id: String { rawValue }

    func includes(_ node: BrowsingNode) -> Bool {
        switch self {
        case .all: return node.isPinned || node.hasNotes
        case .starred: return node.isPinned
        case .notes: return node.hasNotes
        }
    }
}

public struct SavedPagesView: View {
    @EnvironmentObject var appState: AppState
    @State private var query = ""
    @State private var filter: SavedPageFilter = .all
    @State private var copiedNodeId: UUID?
    @State private var copyTask: Task<Void, Never>?

    private var pages: [BrowsingNode] {
        appState.historyStore.getAllNodes().filter { filter.includes($0) && $0.matches(query) }
            .sorted { $0.timestampOpened > $1.timestampOpened }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PageHeading(title: "Saved pages", subtitle: "Stars and notes from across your browsing sessions.")
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search titles, sites, or notes", text: $query).textFieldStyle(.plain)
                    if !query.isEmpty {
                        Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain).accessibilityLabel("Clear saved page search")
                    }
                }.padding(10).background(DNAStyle.surface, in: RoundedRectangle(cornerRadius: 10))
                Picker("Saved page filter", selection: $filter) {
                    ForEach(SavedPageFilter.allCases) { Text($0.rawValue).tag($0) }
                }.labelsHidden().frame(width: 140)
            }
            Text("\(pages.count) saved \(pages.count == 1 ? "page" : "pages")").font(.system(size: 12)).foregroundStyle(.secondary)
            if pages.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    EmptyStateView(icon: "star", title: query.isEmpty && filter == .all ? "Keep useful pages close" : "No matching saved pages",
                        message: query.isEmpty && filter == .all ? "Open a page in a session and star it or add a note. It will appear here." : "Try another search or show all saved pages.")
                    Button("Open session library") { appState.selectedTab = .sessions }.buttonStyle(.borderedProminent)
                    if !query.isEmpty || filter != .all {
                        Button("Clear filters") { query = ""; filter = .all }.buttonStyle(.borderless)
                    }
                    Spacer()
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) { ForEach(pages) { page in row(page) } }.padding(.bottom, 12)
                }
            }
        }.padding(28).background(DNAStyle.background)
    }

    private func row(_ page: BrowsingNode) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                FaviconView(domain: page.domain, fallbackEmoji: page.faviconEmoji, size: 22)
                Button { appState.openPage(page) } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(page.title).font(.system(size: 14, weight: .semibold)).lineLimit(2)
                        Text(page.domain + " · " + page.timestampOpened.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityLabel("Show \(page.title) in its session")
                Button {
                    var changed = page; changed.isPinned.toggle(); appState.updateNode(changed)
                } label: {
                    Image(systemName: page.isPinned ? "star.fill" : "star").foregroundStyle(page.isPinned ? Color.orange : Color.secondary)
                }.buttonStyle(.borderless).accessibilityLabel(page.isPinned ? "Unstar \(page.title)" : "Star \(page.title)")
            }
            if page.hasNotes {
                Text(page.notes ?? "").font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 14) {
                Button("Show in session") { appState.openPage(page) }
                Button("Open in browser") { if let url = page.reopenURL { NSWorkspace.shared.open(url) } }.disabled(page.reopenURL == nil)
                Button(copiedNodeId == page.id ? "Link copied" : "Copy link") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(page.url, forType: .string)
                    copiedNodeId = page.id; copyTask?.cancel()
                    copyTask = Task { @MainActor in
                        try? await Task.sleep(for: .seconds(2))
                        if !Task.isCancelled { copiedNodeId = nil }
                    }
                }
                Spacer()
            }.font(.system(size: 11)).buttonStyle(.borderless)
        }.dnaSurface(padding: 18)
    }
}
