import AppKit
import PreviewCore
import UniformTypeIdentifiers

// Loads bounded UTF-8 Markdown files and builds their native preview interface.
public struct MarkdownModule: PreviewModule {
    public let supportedTypes = [UTType(importedAs: "net.daringfireball.markdown", conformingTo: .plainText)]
    public let layoutKind = PreviewLayoutKind.text

    public init() {}

    public func makePreview(for url: URL) async throws -> NSViewController {
        let reader = Task.detached {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            let limit = 2 * 1024 * 1024
            let data = try handle.read(upToCount: limit + 1) ?? Data()
            try Task.checkCancellation()
            guard data.count <= limit else { throw MarkdownError.tooLarge }
            guard let source = String(data: data, encoding: .utf8) else {
                throw MarkdownError.invalidEncoding
            }
            return source
        }
        let source = try await withTaskCancellationHandler {
            try await reader.value
        } onCancel: {
            reader.cancel()
        }
        try Task.checkCancellation()
        return MarkdownViewController(source: source, fileURL: url)
    }
}

// Describes Markdown input failures in terms that can be shown to the user.
private enum MarkdownError: LocalizedError {
    case tooLarge
    case invalidEncoding

    var errorDescription: String? {
        switch self {
        case .tooLarge: "Markdown preview supports files up to 2 MB."
        case .invalidEncoding: "This file is not valid UTF-8 text."
        }
    }
}
