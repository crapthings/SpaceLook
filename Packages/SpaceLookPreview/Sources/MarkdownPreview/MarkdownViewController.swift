import AppKit
import MarkdownUI
import PreviewUI
import SwiftUI

// Hosts the Markdown module's rendering and source toggle in an AppKit controller.
@MainActor
final class MarkdownViewController: NSHostingController<MarkdownContentView> {
    init(source: String, fileURL: URL) {
        super.init(rootView: MarkdownContentView(source: source, fileURL: fileURL))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init(source:fileURL:).") }
}

// Displays selectable Markdown text with a local switch to its unchanged source.
struct MarkdownContentView: View {
    private let content: MarkdownContent
    private let baseURL: URL
    private let sourceText: NSAttributedString
    @State private var showsSource = false

    init(source: String, fileURL: URL) {
        content = MarkdownContent(source)
        baseURL = fileURL.deletingLastPathComponent()
        sourceText = NSAttributedString(
            string: source,
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
                .foregroundColor: NSColor.textColor
            ]
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Picker("Display", selection: $showsSource) {
                    Image(systemName: "eye").tag(false)
                    Image(systemName: "doc.plaintext").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 84)
                .help(showsSource ? "Show preview" : "Show source")
            }
            .frame(height: 44)
            .padding(.horizontal, 12)
            Divider()
            ZStack {
                ScrollView(.vertical) {
                    Markdown(content, baseURL: baseURL, imageBaseURL: baseURL)
                        .markdownTheme(.gitHub)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(24)
                }
                .opacity(showsSource ? 0 : 1)
                .allowsHitTesting(!showsSource)

                ReadOnlyTextView(sourceText)
                    .opacity(showsSource ? 1 : 0)
                    .allowsHitTesting(showsSource)
            }
        }
        .animation(nil, value: showsSource)
        .background(Color(nsColor: .textBackgroundColor))
    }
}
