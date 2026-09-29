import Foundation
import WebKit

// Serves only bundled viewer assets and the selected GLB through an isolated local URL scheme.
@MainActor
final class ModelResources: NSObject, WKURLSchemeHandler {
    private let modelURL: URL
    private var tasks: [ObjectIdentifier: Task<Void, Never>] = [:]

    init(modelURL: URL) { self.modelURL = modelURL }

    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        let identifier = ObjectIdentifier(urlSchemeTask)
        guard let requestURL = urlSchemeTask.request.url, requestURL.host == "viewer" else {
            urlSchemeTask.didFailWithError(URLError(.unsupportedURL))
            return
        }
        let source: URL
        let mime: String
        let isModel = requestURL.path == "/model.glb"
        switch requestURL.path {
        case "/model.glb": source = modelURL; mime = "model/gltf-binary"
        case "/index.html", "/viewer.js", "/viewer.css":
            guard let resource = Bundle.module.url(forResource: "Resources", withExtension: nil) else {
                urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist)); return
            }
            source = resource.appendingPathComponent(requestURL.lastPathComponent)
            mime = requestURL.path.hasSuffix(".html") ? "text/html" : requestURL.path.hasSuffix(".css") ? "text/css" : "text/javascript"
        default:
            urlSchemeTask.didFailWithError(URLError(.noPermissionsToReadFile)); return
        }
        tasks[identifier] = Task { [weak self] in
            let reader = Task.detached {
                let scoped = source.startAccessingSecurityScopedResource()
                defer { if scoped { source.stopAccessingSecurityScopedResource() } }
                let handle = try FileHandle(forReadingFrom: source)
                defer { try? handle.close() }
                let limit = isModel ? 128 * 1024 * 1024 : 4 * 1024 * 1024
                guard try handle.seekToEnd() <= UInt64(limit) else { throw ModelLoadError.tooLarge }
                try handle.seek(toOffset: 0)
                var data = Data()
                while let chunk = try handle.read(upToCount: 1024 * 1024), !chunk.isEmpty {
                    try Task.checkCancellation()
                    guard data.count + chunk.count <= limit else { throw ModelLoadError.tooLarge }
                    data.append(chunk)
                }
                return data
            }
            do {
                let data = try await withTaskCancellationHandler { try await reader.value } onCancel: { reader.cancel() }
                try Task.checkCancellation()
                let response = HTTPURLResponse(url: requestURL, statusCode: 200, httpVersion: "HTTP/1.1",
                    headerFields: ["Content-Type": mime, "Content-Length": String(data.count)])!
                urlSchemeTask.didReceive(response)
                urlSchemeTask.didReceive(data)
                urlSchemeTask.didFinish()
            } catch {
                if !Task.isCancelled {
                    if isModel {
                        let response = HTTPURLResponse(url: requestURL, statusCode: 422, httpVersion: "HTTP/1.1",
                            headerFields: ["Content-Type": "text/plain; charset=utf-8"])!
                        urlSchemeTask.didReceive(response)
                        urlSchemeTask.didReceive(Data(error.localizedDescription.utf8))
                        urlSchemeTask.didFinish()
                    } else {
                        urlSchemeTask.didFailWithError(error)
                    }
                }
            }
            self?.tasks[identifier] = nil
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {
        tasks.removeValue(forKey: ObjectIdentifier(urlSchemeTask))?.cancel()
    }

    func cancel() {
        tasks.values.forEach { $0.cancel() }
        tasks.removeAll()
    }
}

// Describes the bounded file-loading policy for model previews.
private enum ModelLoadError: LocalizedError {
    case tooLarge
    var errorDescription: String? { "Model preview supports GLB files up to 128 MB." }
}
