import AppKit
import PreviewUI
import SwiftUI

// Hosts a selectable monospaced structured text preview in an AppKit controller.
@MainActor
final class StructuredTextViewController: NSHostingController<ReadOnlyTextView> {
    init(attributedText: NSAttributedString) {
        super.init(rootView: ReadOnlyTextView(attributedText))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init(attributedText:).") }
}
