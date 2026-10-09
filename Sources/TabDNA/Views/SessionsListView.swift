import SwiftUI

public struct SessionsListView: View {
    @EnvironmentObject var appState: AppState
    @State private var search = ""
    @State private var category: SessionCategory?
    @State private var oldestFirst = false
    @State private var sessionToDelete: BrowsingSession?
    @State private var showDeleteAlert = false
    @State private var sessionToRename: BrowsingSession?
    @State private var renameText = ""
    @State private var showRenameSheet = false
    @FocusState private var renameFocused: Bool
    private var filteredSessions: [BrowsingSession] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let sessions = appState.sessions.filter { session in
            let matchesCategory = category == nil || category == session.category
            let matchesSearch =
                query.isEmpty || session.displayTitle.localizedCaseInsensitiveContains(query)
                || session.mainDomains.contains { $0.domain.localizedCaseInsensitiveContains(query) }
            return matchesCategory && matchesSearch
        }
        return sessions.sorted { oldestFirst ? $0.startTime < $1.startTime : $0.startTime > $1.startTime }
    }
    private var days: [Date] {
        Set(filteredSessions.map { Calendar.current.startOfDay(for: $0.startTime) })
            .sorted { oldestFirst ? $0 < $1 : $0 > $1 }
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PageHeading(
                title: "Session library", subtitle: "Search, rename, and revisit your browsing sessions.")
            HStack(spacing: 12) {
                LibrarySearchField(
                    prompt: "Search sessions or sites", clearLabel: "Clear session search", text: $search)
                Picker("Category", selection: $category) {
                    Text("All categories").tag(nil as SessionCategory?)
                    ForEach(SessionCategory.allCases, id: \.self) { Text($0.displayName).tag(Optional($0)) }
                }
                .labelsHidden().frame(width: 170)
                Picker("Sort order", selection: $oldestFirst) {
                    Text("Newest first").tag(false)
                    Text("Oldest first").tag(true)
                }
                .labelsHidden().frame(width: 120)
            }
            HStack {
                Text("\(filteredSessions.count) \(filteredSessions.count == 1 ? "session" : "sessions")")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                Spacer()
                if !search.isEmpty || category != nil {
                    Button("Clear filters", action: clearFilters).buttonStyle(.plain)
                        .foregroundStyle(DNAStyle.accent)
                }
            }
            if filteredSessions.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    EmptyStateView(
                        icon: appState.sessions.isEmpty ? "tray" : "magnifyingglass",
                        title: appState.sessions.isEmpty ? "No sessions yet" : "No matching sessions",
                        message: appState.sessions.isEmpty
                            ? "Start browsing in a supported browser to record a session."
                            : "Try a different title, site, or category.")
                    if appState.sessions.isEmpty {
                        Button("Tracking settings") { appState.selectedTab = .settings }
                            .buttonStyle(.borderedProminent)
                    } else {
                        Button("Clear filters", action: clearFilters).buttonStyle(.bordered)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(days, id: \.self) { day in
                            Text(dayTitle(day)).font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary).padding(.top, 8)
                            ForEach(
                                filteredSessions.filter {
                                    Calendar.current.isDate($0.startTime, inSameDayAs: day)
                                }
                            ) { session in
                                row(session)
                            }
                        }
                    }
                    .padding(.bottom, 10)
                }
            }
        }
        .padding(DNAStyle.pagePadding).background(DNAStyle.background)
        .sheet(isPresented: $showRenameSheet) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Rename session").font(.system(size: 18, weight: .semibold))
                TextField("Session name", text: $renameText).textFieldStyle(.roundedBorder)
                    .focused($renameFocused).onSubmit { saveName() }
                HStack {
                    Text("Up to 120 characters").font(.system(size: 11)).foregroundStyle(.secondary)
                    Spacer()
                    Button("Cancel") { showRenameSheet = false }.keyboardShortcut(.cancelAction)
                    Button("Save") { saveName() }.keyboardShortcut(.defaultAction)
                        .disabled(renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(24).frame(width: 420).onAppear { renameFocused = true }
        }
        .alert("Delete this session?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { sessionToDelete = nil }
            Button("Delete session", role: .destructive) {
                if let sessionToDelete { appState.deleteSession(sessionToDelete) }
                sessionToDelete = nil
            }
        } message: {
            Text(
                "“\(sessionToDelete?.displayTitle ?? "This session")” and its pages will be permanently removed from this Mac."
            )
        }
    }
    private func row(_ session: BrowsingSession) -> some View {
        HStack(spacing: 12) {
            Button {
                appState.selectSession(session)
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: session.category.icon).font(.system(size: 17))
                        .foregroundStyle(session.category.color).frame(width: 42, height: 42)
                        .background(
                            session.category.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(session.displayTitle).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                            if session.isActive {
                                Text("Current").font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(DNAStyle.accent)
                            }
                        }
                        Text(
                            "\(session.formattedTimeRange) · \(session.pageCount) pages · \(session.formattedDuration)"
                        )
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }
            .buttonStyle(PressableCardStyle())
            .accessibilityLabel("Open \(session.displayTitle), \(session.pageCount) pages")
            Menu {
                Button("Rename session…") {
                    sessionToRename = session
                    renameText = session.displayTitle
                    showRenameSheet = true
                }
                Button("Open session") { appState.selectSession(session) }
                Button("Delete session…", role: .destructive) {
                    sessionToDelete = session
                    showDeleteAlert = true
                }
            } label: {
                Image(systemName: "ellipsis").frame(width: 22, height: 24)
            }
            .menuStyle(.borderlessButton).fixedSize()
            .accessibilityLabel("Actions for \(session.displayTitle)")
        }
        .dnaSurface(padding: 16)
    }

    private func clearFilters() {
        search = ""
        category = nil
    }

    private func saveName() {
        guard !renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let sessionToRename else {
            return
        }
        appState.renameSession(sessionToRename, to: renameText)
        showRenameSheet = false
    }
    private func dayTitle(_ day: Date) -> String {
        if Calendar.current.isDateInToday(day) { return "Today" }
        if Calendar.current.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().year())
    }
}
