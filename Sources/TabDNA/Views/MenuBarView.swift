import SwiftUI
import AppKit

public struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openWindow) private var openWindow
    @ObservedObject private var observer = BrowserObserver.shared

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Text("TabDNA")
                    .font(.system(size: 14, weight: .bold))

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(appState.observer.isTrackingEnabled ? Color.green : Color.orange)
                        .frame(width: 7, height: 7)
                    Text(appState.observer.isTrackingEnabled ? "TRACKING: ON" : "PAUSED")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(appState.observer.isTrackingEnabled ? Color.green : Color.orange)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background((appState.observer.isTrackingEnabled ? Color.green : Color.orange).opacity(0.15))
                .clipShape(Capsule())
            }

            // Current Active Tab info if available
            if let tab = appState.observer.currentTabInfo {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tab.browserName)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.secondary)

                    Text(tab.title)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)

                    Text(tab.url)
                        .font(.system(size: 9))
                        .foregroundStyle(Color.secondary)
                        .lineLimit(1)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Divider()

            // Actions
            Button {
                openMainWindow()
            } label: {
                Label("Open TabDNA Window", systemImage: "macwindow")
            }
            .buttonStyle(.plain)

            Button {
                appState.observer.toggleTracking()
            } label: {
                Label(appState.observer.isTrackingEnabled ? "Pause Tracking" : "Resume Tracking",
                      systemImage: appState.observer.isTrackingEnabled ? "pause.fill" : "play.fill")
            }
            .buttonStyle(.plain)

            Button {
                appState.startNewSession()
                openMainWindow()
            } label: {
                Label("Start New Session", systemImage: "plus.circle")
            }
            .buttonStyle(.plain)

            Divider()

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Quit TabDNA", systemImage: "power")
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(width: 260)
    }

    private func openMainWindow() {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }
}
