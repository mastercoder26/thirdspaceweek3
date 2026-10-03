import Foundation

enum ExportFilename {
    static func slug(_ title: String) -> String {
        let slug = title.map { $0.isLetter || $0.isNumber || $0 == "-" ? String($0) : "_" }.joined()
        return slug.isEmpty ? "Session" : String(slug.prefix(40))
    }
}
