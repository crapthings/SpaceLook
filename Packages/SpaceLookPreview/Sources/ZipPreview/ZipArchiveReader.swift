import Foundation
import ZIPFoundation

// Stores the bounded archive metadata needed by the virtual table.
struct ZipArchiveSnapshot: Sendable {
    let entries: [ZipEntryMetadata]
    let totalOriginalSize: UInt64
    let totalCompressedSize: UInt64
    let isTruncated: Bool
}

// Stores preformatted metadata for one ZIP entry without retaining archive data.
struct ZipEntryMetadata: Sendable {
    let name: String
    let folder: String
    let originalSize: String
    let compressedSize: String
    let isDirectory: Bool
}

// Reads only ZIP directory records on a background task with strict metadata limits.
enum ZipArchiveReader {
    private static let maximumEntries = 100_000
    private static let maximumPathBytes = 16 * 1024 * 1024
    private static let maximumDisplayedPathLength = 4_096

    static func read(_ url: URL) async throws -> ZipArchiveSnapshot {
        try await Task.detached(priority: .userInitiated) {
            let archive = try Archive(url: url, accessMode: .read)
            var entries: [ZipEntryMetadata] = []
            entries.reserveCapacity(4_096)
            var pathBytes = 0
            var totalOriginalSize: UInt64 = 0
            var totalCompressedSize: UInt64 = 0
            var isTruncated = false

            for entry in archive {
                try Task.checkCancellation()
                let path = sanitized(entry.path)
                pathBytes += path.utf8.count
                guard entries.count < maximumEntries, pathBytes <= maximumPathBytes else {
                    isTruncated = true
                    break
                }

                let isDirectory = entry.type == .directory
                let parts = path.split(separator: "/", omittingEmptySubsequences: true)
                let name = parts.last.map(String.init) ?? path
                let folder = parts.dropLast().joined(separator: "/")
                let originalSize = UInt64(entry.uncompressedSize)
                let compressedSize = UInt64(entry.compressedSize)
                totalOriginalSize = addingClamped(totalOriginalSize, originalSize)
                totalCompressedSize = addingClamped(totalCompressedSize, compressedSize)
                entries.append(
                    ZipEntryMetadata(
                        name: name,
                        folder: folder,
                        originalSize: isDirectory ? "—" : ByteCountFormatter.string(fromByteCount: clamped(originalSize), countStyle: .file),
                        compressedSize: isDirectory ? "—" : ByteCountFormatter.string(fromByteCount: clamped(compressedSize), countStyle: .file),
                        isDirectory: isDirectory
                    )
                )
            }

            return ZipArchiveSnapshot(
                entries: entries,
                totalOriginalSize: totalOriginalSize,
                totalCompressedSize: totalCompressedSize,
                isTruncated: isTruncated
            )
        }.value
    }

    private static func sanitized(_ path: String) -> String {
        let clean = path.replacingOccurrences(of: "[\\n\\r\\t]", with: " ", options: .regularExpression)
        return String(clean.prefix(maximumDisplayedPathLength))
    }

    private static func clamped(_ size: UInt64) -> Int64 {
        Int64(min(size, UInt64(Int64.max)))
    }

    private static func addingClamped(_ left: UInt64, _ right: UInt64) -> UInt64 {
        let (sum, overflow) = left.addingReportingOverflow(right)
        return overflow ? UInt64.max : sum
    }
}
