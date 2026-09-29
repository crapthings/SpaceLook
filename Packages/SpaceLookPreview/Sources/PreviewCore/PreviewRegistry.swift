import AppKit
import UniformTypeIdentifiers

// Selects the first registered module supporting the file's declared content type.
@MainActor
public struct PreviewRegistry {
    private let modules: [any PreviewModule]

    public init(modules: [any PreviewModule]) {
        self.modules = modules
    }

    public func makePreview(for url: URL) async throws -> PreviewResult {
        let type = try url.resourceValues(forKeys: [.contentTypeKey]).contentType
            ?? UTType(filenameExtension: url.pathExtension)
        guard let type,
              let module = modules.first(where: { module in
                  module.supportedTypes.contains { type.conforms(to: $0) }
              }) else { throw PreviewError.unsupportedFormat }
        let controller = try await module.makePreview(for: url)
        return PreviewResult(controller: controller, layoutKind: module.layoutKind)
    }
}
