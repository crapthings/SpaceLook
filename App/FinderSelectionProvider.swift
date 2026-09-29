import Foundation

// Reads the single file currently selected in Finder through its scripting interface.
struct FinderSelectionProvider {
    func selectedFileURL() throws -> URL {
        let source = """
        tell application "Finder"
            set selectedItems to selection
            if (count of selectedItems) is not 1 then return ""
            return POSIX path of ((item 1 of selectedItems) as alias)
        end tell
        """
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error { throw FinderSelectionError.appleScript(error.description) }
        guard let path = result?.stringValue, !path.isEmpty else {
            throw FinderSelectionError.noSingleSelection
        }
        return URL(fileURLWithPath: path)
    }
}

// Describes failures while resolving Finder's current selection.
private enum FinderSelectionError: LocalizedError {
    case noSingleSelection
    case appleScript(String)

    var errorDescription: String? {
        switch self {
        case .noSingleSelection: "Select exactly one Finder item."
        case .appleScript(let message): "Finder selection failed: \(message)"
        }
    }
}
