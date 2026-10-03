import Foundation

// UI verification builds use their own fixture file and never read real browser tabs.
// These bundle keys have no effect in the distributed release build.
enum RuntimeConfiguration {
    static var isUITest: Bool {
        #if DEBUG
        return Bundle.main.object(forInfoDictionaryKey: "TabDNA_UITestMode") as? Bool == true
        #else
        return false
        #endif
    }

    static var testHistoryURL: URL? {
        #if DEBUG
        if isUITest, let path = Bundle.main.object(forInfoDictionaryKey: "TabDNA_UITestHistoryPath") as? String {
            return URL(fileURLWithPath: path)
        }
        #endif
        return nil
    }
}
