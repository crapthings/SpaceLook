import Foundation
import UniformTypeIdentifiers

// Stores the bounded directory metadata needed by the virtual table.
struct DirectorySnapshot: Sendable {
    let entries: [DirectoryEntryMetadata]
    let isTruncated: Bool
}

// Stores preformatted metadata for one direct child of a directory.
struct DirectoryEntryMetadata: Sendable {
    let name: String
    let kind: String
    let size: String
    let modified: String
    let isDirectory: Bool
}

// Enumerates one directory level on a background task without calculating recursive sizes.
enum DirectoryReader {
    private static let maximumEntries = 100_000
    private static let maximumNameBytes = 16 * 1024 * 1024
    private static let maximumDisplayedNameLength = 4_096

    static func read(_ url: URL) async throws -> DirectorySnapshot {
        try await Task.detached(priority: .userInitiated) {
            let keys: [URLResourceKey] = [
                .nameKey,
                .isDirectoryKey,
                .fileSizeKey,
                .contentTypeKey,
                .contentModificationDateKey
            ]
            guard let enumerator = FileManager.default.enumerator(
                at: url,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants, .skipsSubdirectoryDescendants]
            ) else { throw DirectoryReadError.unavailable }

            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            var entries: [DirectoryEntryMetadata] = []
            entries.reserveCapacity(1_024)
            var nameBytes = 0
            var isTruncated = false

            while let childURL = enumerator.nextObject() as? URL {
                try Task.checkCancellation()
                let values = try childURL.resourceValues(forKeys: Set(keys))
                let name = sanitized(values.name ?? childURL.lastPathComponent)
                nameBytes += name.utf8.count
                guard entries.count < maximumEntries, nameBytes <= maximumNameBytes else {
                    isTruncated = true
                    break
                }
                let isDirectory = values.isDirectory == true
                let size = isDirectory ? "—" : ByteCountFormatter.string(
                    fromByteCount: Int64(values.fileSize ?? 0),
                    countStyle: .file
                )
                entries.append(
                    DirectoryEntryMetadata(
                        name: name,
                        kind: isDirectory ? "Folder" : values.contentType?.localizedDescription ?? "File",
                        size: size,
                        modified: values.contentModificationDate.map(dateFormatter.string(from:)) ?? "—",
                        isDirectory: isDirectory
                    )
                )
            }

            entries.sort {
                if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            return DirectorySnapshot(entries: entries, isTruncated: isTruncated)
        }.value
    }

    private static func sanitized(_ name: String) -> String {
        let clean = name.replacingOccurrences(of: "[\\n\\r\\t]", with: " ", options: .regularExpression)
        return String(clean.prefix(maximumDisplayedNameLength))
    }
}

// Describes a directory that cannot be enumerated.
private enum DirectoryReadError: LocalizedError {
    case unavailable

    var errorDescription: String? { "This folder cannot be read." }
}
