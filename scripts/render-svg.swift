import AppKit
import WebKit

// Renders a local SVG to an exact-size transparent PNG using macOS WebKit.
@MainActor
final class SVGRenderer: NSObject, WKNavigationDelegate {
    let webView: WKWebView
    let destination: URL
    let pixels: Int

    init(source: URL, destination: URL, pixels: Int) throws {
        self.destination = destination
        self.pixels = pixels
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: pixels, height: pixels))
        super.init()
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = self
        let svg = try String(contentsOf: source, encoding: .utf8)
        webView.loadHTMLString("<style>html,body{margin:0;background:transparent}svg{width:100vw;height:100vh;display:block}</style>" + svg, baseURL: nil)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let configuration = WKSnapshotConfiguration()
        configuration.snapshotWidth = NSNumber(value: pixels)
        webView.takeSnapshot(with: configuration) { [self] image, error in
            do {
                if let error { throw error }
                guard let image,
                      let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                          bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                          colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
                      let context = NSGraphicsContext(bitmapImageRep: bitmap) else { exit(1) }
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = context
                image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
                NSGraphicsContext.restoreGraphicsState()
                try bitmap.representation(using: .png, properties: [:])!.write(to: destination)
                exit(0)
            } catch {
                fputs("SVG rendering failed: \(error)\n", stderr)
                exit(1)
            }
        }
    }
}

// Keeps the renderer alive while WebKit loads and snapshots its SVG document.
@main
struct RenderSVG {
    @MainActor static func main() throws {
        let application = NSApplication.shared
        application.setActivationPolicy(.prohibited)
        guard CommandLine.arguments.count == 4, let pixels = Int(CommandLine.arguments[3]), pixels > 0 else {
            fatalError("Usage: render-svg source.svg destination.png pixels")
        }
        let renderer = try SVGRenderer(source: URL(fileURLWithPath: CommandLine.arguments[1]),
                                       destination: URL(fileURLWithPath: CommandLine.arguments[2]), pixels: pixels)
        withExtendedLifetime(renderer) { application.run() }
    }
}
