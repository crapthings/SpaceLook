import AppKit
import SwiftUI

// Presents read-only text with editor-like sizing, selection, and scrolling behavior.
public struct ReadOnlyTextView: NSViewRepresentable {
    private let attributedText: NSAttributedString

    public init(_ text: String) {
        attributedText = NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
                .foregroundColor: NSColor.textColor
            ]
        )
    }

    public init(_ attributedText: NSAttributedString) {
        self.attributedText = attributedText
    }

    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor

        let textView = NSTextView()
        textView.textStorage?.setAttributedString(attributedText)
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = NSSize(width: 16, height: 16)
        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = true
        textView.minSize = .zero
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        applyBackground(from: attributedText, to: textView, scrollView: scrollView)
        scrollView.documentView = textView
        return scrollView
    }

    public func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView,
              !textView.attributedString().isEqual(to: attributedText) else { return }
        textView.textStorage?.setAttributedString(attributedText)
        applyBackground(from: attributedText, to: textView, scrollView: scrollView)
    }

    private func applyBackground(
        from text: NSAttributedString,
        to textView: NSTextView,
        scrollView: NSScrollView
    ) {
        let color = text.length > 0
            ? text.attribute(.backgroundColor, at: 0, effectiveRange: nil) as? NSColor
            : nil
        let background = color ?? .textBackgroundColor
        textView.backgroundColor = background
        scrollView.backgroundColor = background
    }
}
