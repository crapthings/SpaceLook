import DirectoryPreview
import MarkdownPreview
import PreviewCore
import StructuredTextPreview
import ZipPreview

// Exposes the shared layout family without requiring clients to import internal modules.
public typealias PreviewLayoutKind = PreviewCore.PreviewLayoutKind

// Composes built-in format modules for the app and Quick Look extension.
@MainActor
public enum BuiltInPreviews {
    public static func makeRegistry() -> PreviewRegistry {
        PreviewRegistry(modules: [DirectoryModule(), MarkdownModule(), StructuredTextModule(), ZipModule()])
    }
}
