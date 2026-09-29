import AppKit
import PreviewCore
import UniformTypeIdentifiers

// Creates a metadata-only preview for ZIP archives without extracting their contents.
public struct ZipModule: PreviewModule {
    public let supportedTypes = [UTType.zip]
    public let layoutKind = PreviewLayoutKind.table

    public init() {}

    public func makePreview(for url: URL) async throws -> NSViewController {
        ZipPreviewViewController(url: url)
    }
}
