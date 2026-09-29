import AppKit
import PreviewCore
import UniformTypeIdentifiers

// Opens a GLB viewer immediately so loading feedback precedes file reading and GPU work.
public struct ModelModule: PreviewModule {
    public let supportedTypes = [UTType(importedAs: "org.khronos.glb", conformingTo: .data)]
    public let layoutKind = PreviewLayoutKind.model

    public init() {}

    public func makePreview(for url: URL) async throws -> NSViewController {
        ModelViewController(url: url)
    }
}
