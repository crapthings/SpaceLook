import AppKit
import PreviewCore
import PreviewUI
import UniformTypeIdentifiers

// Loads bounded JSON and YAML files and prepares their structured text previews.
public struct StructuredTextModule: PreviewModule {
    private static let yamlType = UTType(importedAs: "public.yaml", conformingTo: .text)
    public let supportedTypes = [UTType.json, Self.yamlType]
    public let layoutKind = PreviewLayoutKind.text

    public init() {}

    public func makePreview(for url: URL) async throws -> NSViewController {
        let source = try await Task.detached {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            let limit = 2 * 1024 * 1024
            let data = try handle.read(upToCount: limit + 1) ?? Data()
            try Task.checkCancellation()
            guard data.count <= limit else { throw StructuredTextError.tooLarge }
            guard let source = String(data: data, encoding: .utf8) else {
                throw StructuredTextError.invalidEncoding
            }
            return source
        }.value

        let language = url.pathExtension.lowercased() == "json" ? "json" : "yaml"
        let darkMode = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let highlighted = await SyntaxHighlighter.highlight(
            source,
            language: language,
            darkMode: darkMode
        )
        return StructuredTextViewController(attributedText: highlighted)
    }
}

// Describes structured text input failures in user-facing terms.
private enum StructuredTextError: LocalizedError {
    case tooLarge
    case invalidEncoding

    var errorDescription: String? {
        switch self {
        case .tooLarge: "Structured text preview supports files up to 2 MB."
        case .invalidEncoding: "This file is not valid UTF-8 text."
        }
    }
}
