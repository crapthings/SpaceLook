import AppKit
import PreviewCore
import UniformTypeIdentifiers

// Creates a shallow metadata preview for ordinary filesystem directories.
public struct DirectoryModule: PreviewModule {
    public let supportedTypes = [UTType.folder]
    public let layoutKind = PreviewLayoutKind.table

    public init() {}

    public func makePreview(for url: URL) async throws -> NSViewController {
        DirectoryPreviewViewController(url: url)
    }
}
