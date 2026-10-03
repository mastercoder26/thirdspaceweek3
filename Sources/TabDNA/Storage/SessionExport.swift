import AppKit
import UniformTypeIdentifiers

enum ExportResult {
    case saved(URL)
    case cancelled
    case failed(String)
}

@MainActor
enum SessionExport {
    static func save(session: BrowsingSession, fileExtension: String, type: UTType,
                     data: () throws -> Data) -> ExportResult {
        let panel = NSSavePanel()
        panel.title = "Export session"
        panel.nameFieldStringValue = "TabDNA_\(ExportFilename.slug(session.displayTitle)).\(fileExtension)"
        panel.allowedContentTypes = [type]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let destination = panel.url else { return .cancelled }
        do {
            try data().write(to: destination, options: .atomic)
            return .saved(destination)
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}
