import SwiftUI
import AppKit

public struct CommandItem: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let icon: String
    public let category: String
    public let action: @Sendable @MainActor () -> Void

    public init(
        id: String = "",
        title: String,
        subtitle: String = "",
        icon: String,
        category: String = "Actions",
        action: @escaping @Sendable @MainActor () -> Void
    ) {
        self.id = id.isEmpty ? title : id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.category = category
        self.action = action
    }
}

public struct CommandPaletteView: View {
    @EnvironmentObject var appState: AppState
    @Binding public var isPresented: Bool

    @State private var searchText: String = ""
    @State private var selectedIndex: Int = 0
    @FocusState private var searchFocused: Bool

    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }

    private var allCommands: [CommandItem] {
        var items: [CommandItem] = []

        // Navigation & Actions
        items.append(CommandItem(
            title: appState.observer.isTrackingEnabled ? "Pause Browser Tracking" : "Resume Browser Tracking",
            subtitle: "Global tracking status",
            icon: appState.observer.isTrackingEnabled ? "pause.circle.fill" : "play.circle.fill",
            category: "Tracking"
        ) {
            appState.observer.toggleTracking()
            isPresented = false
        })

        items.append(CommandItem(
            title: "Start New Browsing Session",
            subtitle: "Begin a new tree root",
            icon: "plus.circle.fill",
            category: "Sessions"
        ) {
            appState.startNewSession()
            isPresented = false
        })

        items.append(CommandItem(
            title: "Go to Overview",
            subtitle: "View statistics & recent sessions",
            icon: "square.grid.2x2.fill",
            category: "Navigation"
        ) {
            appState.selectedTab = .dashboard
            isPresented = false
        })

        items.append(CommandItem(
            title: "Open Session Library",
            subtitle: "Filter and manage recorded sessions",
            icon: "list.bullet.indent",
            category: "Navigation"
        ) {
            appState.selectedTab = .sessions
            isPresented = false
        })

        items.append(CommandItem(
            title: "Go to Insights",
            subtitle: "Browsing time, sites, and categories",
            icon: "chart.bar.xaxis",
            category: "Navigation"
        ) {
            appState.selectedTab = .statistics
            isPresented = false
        })

        items.append(CommandItem(
            title: "Go to Settings & Privacy",
            subtitle: "Blacklisted domains & tracking settings",
            icon: "gearshape.fill",
            category: "Navigation"
        ) {
            appState.selectedTab = .settings
            isPresented = false
        })

        for session in appState.sessions {
            items.append(CommandItem(id: "session-" + session.id.uuidString,
                title: session.displayTitle, subtitle: "\(session.pageCount) pages · \(session.formattedTimeRange)",
                icon: session.category.icon, category: "Sessions") {
                appState.selectSession(session)
                isPresented = false
            })
        }

        items.append(CommandItem(title: "Open Saved Pages", subtitle: "Stars and personal notes", icon: "star", category: "Navigation") {
            appState.selectedTab = .saved
            isPresented = false
        })

        // Dynamic search over past recorded nodes sorted by recency
        let allNodes = appState.historyStore.getAllNodes().sorted(by: { $0.timestampOpened > $1.timestampOpened })
        let pageMatches: [BrowsingNode]
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if trimmedQuery.isEmpty {
            pageMatches = Array(allNodes.prefix(8))
        } else {
            pageMatches = Array(allNodes.filter { $0.matches(trimmedQuery) }.prefix(25))
        }

        for node in pageMatches {
            items.append(CommandItem(
                id: node.id.uuidString,
                title: node.title,
                subtitle: "\(node.domain) · \(node.hasNotes ? (node.notes ?? "") : node.formattedTime)",
                icon: "doc.text.fill",
                category: "Pages Visited"
            ) {
                appState.openPage(node)
                isPresented = false
            })
        }

        return items
    }

    private var filteredCommands: [CommandItem] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return allCommands
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return allCommands.filter {
            $0.category == "Pages Visited" || $0.title.lowercased().contains(query) ||
            $0.subtitle.lowercased().contains(query) ||
            $0.category.lowercased().contains(query)
        }
    }

    public var body: some View {
        let results = Array(filteredCommands.prefix(15))
        ZStack {
            // Scrim
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }

            // Modal Card
            VStack(spacing: 0) {
                // Search Input Header
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.secondary)

                    TextField("Type a command, page title, or domain...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15))
                        .focused($searchFocused)
                        .onKeyPress(.downArrow) {
                            selectedIndex = min(max(0, min(15, filteredCommands.count) - 1), selectedIndex + 1)
                            return .handled
                        }
                        .onKeyPress(.upArrow) { selectedIndex = max(0, selectedIndex - 1); return .handled }
                        .onSubmit {
                            executeSelected()
                        }

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Text("ESC")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .padding(16)
                .background(Color.primary.opacity(0.03))

                Divider()

                // Results List
                ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(results.enumerated()), id: \.element.id) { index, item in
                            let isHighlighted = (index == selectedIndex)

                            Button {
                                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                                item.action()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: item.icon)
                                        .font(.system(size: 14))
                                        .foregroundStyle(isHighlighted ? Color.white : DNAStyle.accent)
                                        .frame(width: 24, height: 24)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.title)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(isHighlighted ? Color.white : Color.primary)
                                            .lineLimit(1)

                                        if !item.subtitle.isEmpty {
                                            Text(item.subtitle)
                                                .font(.system(size: 11))
                                                .foregroundStyle(isHighlighted ? Color.white.opacity(0.8) : Color.secondary)
                                                .lineLimit(1)
                                        }
                                    }

                                    Spacer()

                                    Text(item.category)
                                        .font(.system(size: 10, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(isHighlighted ? Color.white.opacity(0.2) : Color.primary.opacity(0.06))
                                        .foregroundStyle(isHighlighted ? Color.white : Color.secondary)
                                        .clipShape(Capsule())
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(isHighlighted ? DNAStyle.accent : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            .id(item.id)
                        }
                        if filteredCommands.isEmpty {
                            EmptyStateView(icon: "magnifyingglass", title: "No results", message: "Try a page title, site, session, or command.")
                        }
                    }
                    .padding(8)
                }
                .frame(height: min(380, max(100, CGFloat(results.count) * 58 + 16)))
                .onChange(of: selectedIndex) { _, index in
                    if results.indices.contains(index) { proxy.scrollTo(results[index].id) }
                }
                }
                HStack {
                    Text("↑ ↓ Navigate     ↵ Open")
                    Spacer()
                    Text("esc Close")
                }.font(.system(size: 10)).foregroundStyle(.secondary).padding(12)
            }
            .frame(width: 560)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.25), radius: 24, x: 0, y: 12)
        }
        .onAppear {
            selectedIndex = 0
            searchFocused = true
        }
        .onExitCommand { isPresented = false }
        .onChange(of: searchText) { _, _ in
            selectedIndex = 0
        }
    }

    private func executeSelected() {
        let matches = filteredCommands
        if selectedIndex >= 0 && selectedIndex < matches.count {
            matches[selectedIndex].action()
        }
    }
}
