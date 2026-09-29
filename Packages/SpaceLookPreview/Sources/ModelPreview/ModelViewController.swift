import AppKit
import WebKit

// Hosts the offline model viewer with native loading feedback and explicit lifecycle cleanup.
@MainActor
final class ModelViewController: NSViewController, WKNavigationDelegate {
    private let resources: ModelResources
    private var webView: WKWebView?
    private let overlay = NSStackView()
    private let spinner = NSProgressIndicator()
    private let status = NSTextField(wrappingLabelWithString: "Loading model…")
    private let bridge = ModelMessageHandler()
    private var timeoutTask: Task<Void, Never>?

    init(url: URL) {
        resources = ModelResources(modelURL: url)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init(url:).") }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        spinner.style = .spinning
        spinner.controlSize = .regular
        status.alignment = .center
        overlay.orientation = .vertical
        overlay.spacing = 12
        overlay.addArrangedSubview(spinner)
        overlay.addArrangedSubview(status)
        overlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            overlay.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            overlay.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -48)
        ])
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        guard webView == nil else { return }
        overlay.isHidden = false
        status.stringValue = "Loading model…"
        spinner.isHidden = false
        spinner.startAnimation(nil)
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.setURLSchemeHandler(resources, forURLScheme: "spacelook-model")
        bridge.receive = { [weak self] message in
            guard let self else { return }
            switch message {
            case "ready":
                self.timeoutTask?.cancel()
                self.spinner.stopAnimation(nil)
                self.overlay.isHidden = true
                self.webView?.isHidden = false
            default: self.showError(message)
            }
        }
        configuration.userContentController.add(bridge, name: "modelStatus")
        let web = WKWebView(frame: view.bounds, configuration: configuration)
        web.autoresizingMask = [.width, .height]
        web.navigationDelegate = self
        view.addSubview(web, positioned: .below, relativeTo: overlay)
        webView = web
        web.load(URLRequest(url: URL(string: "spacelook-model://viewer/index.html")!))
        timeoutTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(45)) } catch { return }
            self?.showError("This model is taking too long to load. Try a smaller GLB or reopen the preview.")
            self?.webView?.stopLoading()
        }
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        resources.cancel()
        timeoutTask?.cancel()
        webView?.stopLoading()
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "modelStatus")
        webView?.removeFromSuperview()
        webView = nil
        spinner.stopAnimation(nil)
    }

    private func showError(_ message: String) {
        timeoutTask?.cancel()
        spinner.stopAnimation(nil)
        spinner.isHidden = true
        status.stringValue = message
        overlay.isHidden = false
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        showError("Could not load the model preview. \(error.localizedDescription)")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
        showError("Could not load the model preview. \(error.localizedDescription)")
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        showError("The model viewer stopped. Close and reopen the preview to try again.")
    }
}

// Relays viewer status without retaining its owning view controller.
@MainActor
private final class ModelMessageHandler: NSObject, WKScriptMessageHandler {
    var receive: ((String) -> Void)?
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let value = message.body as? String else { return }
        receive?(value)
    }
}
