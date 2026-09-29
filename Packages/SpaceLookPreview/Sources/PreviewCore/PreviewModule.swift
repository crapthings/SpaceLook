import AppKit
import UniformTypeIdentifiers

// Identifies preview families that should share a remembered window size.
public enum PreviewLayoutKind: String, Sendable {
    case text
    case table
    case model
}

// Couples a module-owned controller with its preferred window layout family.
public struct PreviewResult {
    public let controller: NSViewController
    public let layoutKind: PreviewLayoutKind

    public init(controller: NSViewController, layoutKind: PreviewLayoutKind) {
        self.controller = controller
        self.layoutKind = layoutKind
    }
}

// Defines the file types and preview controller supplied by a format module.
@MainActor
public protocol PreviewModule {
    var supportedTypes: [UTType] { get }
    var layoutKind: PreviewLayoutKind { get }
    func makePreview(for url: URL) async throws -> NSViewController
}

// Reports failures that are independent of a specific preview format.
public enum PreviewError: LocalizedError {
    case unsupportedFormat

    public var errorDescription: String? { "This file format is not supported." }
}
