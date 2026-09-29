import AppKit
import Highlighter

// Converts source text to highlighted attributed text without blocking the main actor.
public enum SyntaxHighlighter {
    public static func highlight(_ source: String, language: String, darkMode: Bool) async -> NSAttributedString {
        let result = await Task.detached {
            let fallback = NSAttributedString(
                string: source,
                attributes: [
                    .font: NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
                    .foregroundColor: NSColor.textColor
                ]
            )
            guard let highlighter = Highlighter() else {
                return SendableAttributedText(fallback)
            }
            let theme = darkMode ? "github-dark" : "github"
            highlighter.setTheme(theme, withFont: "Menlo-Regular", ofSize: NSFont.systemFontSize)
            return SendableAttributedText(highlighter.highlight(source, as: language) ?? fallback)
        }.value
        return result.value
    }
}

// Carries immutable attributed text across the background highlighting boundary.
private struct SendableAttributedText: @unchecked Sendable {
    let value: NSAttributedString

    init(_ value: NSAttributedString) {
        self.value = value
    }
}
