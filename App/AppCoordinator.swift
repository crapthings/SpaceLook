import AppKit
import ApplicationServices

// Coordinates accessibility permission, Finder key interception, and the custom preview panel.
@MainActor
final class AppCoordinator: NSObject, NSApplicationDelegate {
    private let selectionProvider = FinderSelectionProvider()
    private let previewPanel = PreviewPanelController()
    private var keyMonitor: GlobalKeyMonitor?
    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        requestAccessibilityPermission()
        startKeyMonitorWhenAllowed()
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissionTimer?.invalidate()
        keyMonitor?.stop()
    }

    private func requestAccessibilityPermission() {
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    private func startKeyMonitorWhenAllowed() {
        guard AXIsProcessTrusted() else {
            permissionTimer = Timer.scheduledTimer(
                timeInterval: 1,
                target: self,
                selector: #selector(checkAccessibilityPermission),
                userInfo: nil,
                repeats: true
            )
            return
        }
        installKeyMonitor()
    }

    @objc private func checkAccessibilityPermission() {
        guard AXIsProcessTrusted() else { return }
        permissionTimer?.invalidate()
        permissionTimer = nil
        installKeyMonitor()
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        let monitor = GlobalKeyMonitor(
            isPreviewVisible: { [weak self] in self?.previewPanel.isVisible == true },
            onSpace: { [weak self] in self?.handleSpace() },
            onEscape: { [weak self] in self?.closePreview() }
        )
        guard monitor.start() else { return }
        keyMonitor = monitor
    }

    private func handleSpace() {
        if previewPanel.isVisible {
            closePreview()
            return
        }

        guard let url = try? selectionProvider.selectedFileURL() else {
            keyMonitor?.passSpaceToSystem()
            return
        }

        let finder = NSWorkspace.shared.frontmostApplication
        previewPanel.show(url: url) { [weak self] in
            self?.keyMonitor?.passSpaceToSystem()
        }
        previewPanel.onClose = { finder?.activate() }
    }

    private func closePreview() {
        previewPanel.close()
    }
}
