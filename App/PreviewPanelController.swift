import AppKit
import PreviewModules

// Owns the resizable floating preview window and remembers frames by layout family.
@MainActor
final class PreviewPanelController: NSObject, NSWindowDelegate {
    var onClose: (() -> Void)?
    var isVisible: Bool { window?.isVisible == true }
    private var window: NSWindow?
    private var loadTask: Task<Void, Never>?
    private var layoutKind: PreviewLayoutKind?
    private var isUpdatingContent = false

    func show(url: URL, onFailure: @escaping () -> Void) {
        loadTask?.cancel()
        loadTask = Task {
            do {
                let result = try await BuiltInPreviews.makeRegistry().makePreview(for: url)
                try Task.checkCancellation()
                let window = makeWindow()
                if window.isVisible { saveFrame(of: window) }
                isUpdatingContent = true
                defer { isUpdatingContent = false }
                window.title = url.lastPathComponent
                window.contentViewController = result.controller
                window.styleMask.insert(.resizable)
                window.contentMinSize = NSSize(width: 420, height: 300)
                layoutKind = result.layoutKind
                restoreFrame(for: result.layoutKind, in: window)
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            } catch {
                guard !Task.isCancelled else { return }
                onFailure()
            }
        }
    }

    func close() {
        loadTask?.cancel()
        loadTask = nil
        guard let window, window.isVisible else { return }
        saveFrame(of: window)
        window.orderOut(nil)
        onClose?()
        onClose = nil
    }

    private func makeWindow() -> NSWindow {
        if let window { return window }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 420, height: 300)
        window.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
        window.level = .floating
        window.standardWindowButton(.zoomButton)?.isEnabled = true
        window.delegate = self
        self.window = window
        return window
    }

    func windowDidResize(_ notification: Notification) {
        guard let window else { return }
        saveFrame(of: window)
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        guard let window else { return }
        saveFrame(of: window)
    }

    func windowDidMove(_ notification: Notification) {
        guard let window else { return }
        saveFrame(of: window)
    }

    private func saveFrame(of window: NSWindow) {
        guard !isUpdatingContent, window.isVisible, let layoutKind else { return }
        window.saveFrame(usingName: frameName(for: layoutKind))
    }

    private func restoreFrame(for layoutKind: PreviewLayoutKind, in window: NSWindow) {
        let name = frameName(for: layoutKind)
        if window.setFrameUsingName(name, force: true) {
            window.setFrame(window.constrainFrameRect(window.frame, to: window.screen), display: false)
            return
        }

        let fallback = layoutKind == .table
            ? NSSize(width: 900, height: 600)
            : NSSize(width: 800, height: 600)
        window.setContentSize(fallback)
        center(window)
    }

    private func frameName(for layoutKind: PreviewLayoutKind) -> NSWindow.FrameAutosaveName {
        NSWindow.FrameAutosaveName("SpaceLookPreview.\(layoutKind.rawValue)")
    }

    private func screenForMouse() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouseLocation) }
    }

    private func center(_ window: NSWindow) {
        let screen = screenForMouse() ?? NSScreen.main
        guard let visibleFrame = screen?.visibleFrame else {
            window.center()
            return
        }
        let origin = NSPoint(
            x: visibleFrame.midX - window.frame.width / 2,
            y: visibleFrame.midY - window.frame.height / 2
        )
        window.setFrameOrigin(origin)
    }
}
