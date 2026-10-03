import SwiftUI
import AppKit
import UniformTypeIdentifiers

public struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var observer = BrowserObserver.shared
    @State private var domainInput = ""
    @State private var blacklist: [String] = []
    @State private var showWipeAlert = false
    @State private var showResetAlert = false
    @State private var exportMessage = ""
    @State private var exportFailed = false
    @AppStorage("TabDNA_PollingInterval") private var pollingInterval: Double = 2
    @AppStorage("TabDNA_InactivityMinutes") private var inactivityMinutes: Double = 25
    @AppStorage("TabDNA_LoadSiteIcons") private var loadSiteIcons = false
    private var validDomain: String? { PrivacyManager.normalizedDomain(domainInput) }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeading(title: "Settings & privacy", subtitle: "Your browsing history, on your terms.")
                section("Browser tracking", icon: "binoculars") {
                    Toggle(isOn: Binding(get: { observer.isTrackingEnabled }, set: { enabled in
                        enabled ? observer.startTracking() : observer.pauseTracking()
                    })) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Record browsing activity").font(.system(size: 13, weight: .medium))
                            Text("Records the active tab while a supported browser is in front.").font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                    }.toggleStyle(.switch)
                    Divider()
                    settingSlider(title: "Check for page changes", subtitle: "Every \(pollingInterval.formatted(.number.precision(.fractionLength(1)))) seconds", value: $pollingInterval, range: 1...8, step: 0.5)
                    Divider()
                    settingSlider(title: "Start a new session after inactivity", subtitle: "After \(Int(inactivityMinutes)) minutes away", value: $inactivityMinutes, range: 10...60, step: 5)
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Supported browsers").font(.system(size: 12, weight: .semibold))
                        Text("Comet, Chrome, Safari, Brave, Arc, Edge, Opera, Vivaldi, and Chromium.")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                        Text("When macOS asks, allow TabDNA to read tabs in the browser you use. If a browser cannot be read, check System Settings → Privacy & Security → Automation.")
                            .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
                section("Excluded sites", icon: "hand.raised") {
                    Text("These domains and their subdomains are skipped. Changes apply to future visits; existing pages stay in your library.")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                    HStack {
                        TextField("example.com", text: $domainInput).textFieldStyle(.roundedBorder).onSubmit { addDomain() }
                        Button("Exclude site") { addDomain() }.buttonStyle(.borderedProminent).disabled(validDomain == nil)
                    }
                    if !domainInput.isEmpty && validDomain == nil {
                        Text("Enter a domain such as example.com, or paste a website URL.").font(.system(size: 11)).foregroundStyle(.red)
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 8)], spacing: 8) {
                        ForEach(blacklist, id: \.self) { domain in
                            HStack {
                                Text(domain).font(.system(size: 11)).lineLimit(1)
                                Spacer()
                                Button { appState.privacyManager.removeDomain(domain); reloadDomains() } label: { Image(systemName: "xmark") }
                                    .buttonStyle(.borderless).accessibilityLabel("Allow future visits to \(domain)")
                            }.padding(10).background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    Button("Restore default exclusions…") { showResetAlert = true }.buttonStyle(.borderless)
                }
                section("Session naming & site icons", icon: "tag") {
                    Label("Session naming runs on this Mac", systemImage: "checkmark.shield")
                        .font(.system(size: 13, weight: .medium))
                    Text("Session names and categories are suggested from page titles on this Mac. You can rename any session in the library.")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                    Divider()
                    Toggle("Download website icons", isOn: $loadSiteIcons).toggleStyle(.switch)
                    Text("When enabled, domains are sent to Google’s favicon service to retrieve icons. Otherwise, TabDNA uses cached icons and local symbols.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                section("Your data", icon: "externaldrive") {
                    Text("\(appState.sessions.count) sessions saved locally in Application Support/TabDNA.").font(.system(size: 12)).foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        Button { exportData() } label: { Label("Export history as JSON…", systemImage: "square.and.arrow.up") }
                        Button("Show data folder") {
                            let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("TabDNA")
                            NSWorkspace.shared.open(url)
                        }
                        Spacer()
                    }
                    if !exportMessage.isEmpty {
                        Text(exportMessage).font(.system(size: 11)).foregroundStyle(exportFailed ? Color.red : Color.green).textSelection(.enabled)
                    }
                    Divider()
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Clear browsing history").font(.system(size: 12, weight: .medium))
                            Text("Permanently removes all sessions and notes.").font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Clear history…", role: .destructive) { showWipeAlert = true }.disabled(appState.sessions.isEmpty)
                    }
                }
            }.padding(28).frame(maxWidth: 900).frame(maxWidth: .infinity)
        }.background(DNAStyle.background)
        .onAppear { reloadDomains() }
        .onChange(of: pollingInterval) { _, value in observer.pollingInterval = value }
        .onChange(of: inactivityMinutes) { _, value in observer.inactivityThreshold = value * 60 }
        .alert("Clear all browsing history?", isPresented: $showWipeAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear history", role: .destructive) { appState.clearAllHistory() }
        } message: { Text("All sessions, pages, stars, and notes will be permanently deleted. This cannot be undone.") }
        .alert("Restore default exclusions?", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Restore defaults") { appState.privacyManager.resetToDefaults(); reloadDomains() }
        } message: { Text("Your custom exclusions will be replaced by the default list of sensitive sites.") }
    }
    private func section<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(DNAStyle.accent)
            content()
        }.frame(maxWidth: .infinity, alignment: .leading).dnaSurface()
    }
    private func settingSlider(title: String, subtitle: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary).monospacedDigit()
            }
            Spacer()
            Slider(value: value, in: range, step: step).frame(width: 180).accessibilityLabel(title)
        }
    }
    private func reloadDomains() { blacklist = appState.privacyManager.getBlacklist() }
    private func addDomain() {
        guard let validDomain else { return }
        appState.privacyManager.addDomain(validDomain); domainInput = ""; reloadDomains()
    }
    private func exportData() {
        let panel = NSSavePanel()
        panel.title = "Export browsing history"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "TabDNA-history.json"
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        do {
            let source = try appState.historyStore.exportJSON()
            try Data(contentsOf: source).write(to: destination, options: .atomic)
            exportFailed = false; exportMessage = "Saved to \(destination.path)"
        } catch { exportFailed = true; exportMessage = "Couldn’t export: \(error.localizedDescription)" }
    }
}
