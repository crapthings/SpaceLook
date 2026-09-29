import AppKit
import PreviewModules
import QuickLookUI

// Adapts Quick Look file requests to the shared preview module registry.
final class PreviewViewController: NSViewController, @preconcurrency QLPreviewingController {
    private var previewTask: Task<Void, Never>?

    override func loadView() {
        view = NSView()
        preferredContentSize = NSSize(width: 800, height: 600)
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping @Sendable (Error?) -> Void) {
        previewTask?.cancel()
        previewTask = Task { @MainActor in
            do {
                let result = try await BuiltInPreviews.makeRegistry().makePreview(for: url)
                try Task.checkCancellation()
                children.forEach { $0.view.removeFromSuperview(); $0.removeFromParent() }
                let controller = result.controller
                addChild(controller)
                controller.view.frame = view.bounds
                controller.view.autoresizingMask = [.width, .height]
                view.addSubview(controller.view)
                handler(nil)
            } catch {
                handler(error)
            }
        }
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        previewTask?.cancel()
    }
}
