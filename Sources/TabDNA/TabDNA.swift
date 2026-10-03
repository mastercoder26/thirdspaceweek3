import SwiftUI
import AppKit

@main
struct TabDNAApp: App {
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        Window("TabDNA", id: "main") {
            MainContainerView()
                .environmentObject(appState)
                .frame(minWidth: 880, minHeight: 620)
                .tint(DNAStyle.accent)
                .accentColor(DNAStyle.accent)
        }
        .defaultSize(width: 1180, height: 790)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)

        MenuBarExtra("TabDNA", systemImage: appState.menuBarIconName) {
            MenuBarView()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)
    }
}
