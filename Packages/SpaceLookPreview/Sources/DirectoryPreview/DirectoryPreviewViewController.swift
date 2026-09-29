import AppKit

// Presents direct folder children in an AppKit table that creates only visible row views.
@MainActor
final class DirectoryPreviewViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    private let url: URL
    private let tableView = NSTableView()
    private let summaryLabel = NSTextField(labelWithString: "Reading folder…")
    private let progressIndicator = NSProgressIndicator()
    private var entries: [DirectoryEntryMetadata] = []
    private var loadTask: Task<Void, Never>?

    init(url: URL) {
        self.url = url
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("Use init(url:).") }

    override func loadView() {
        let container = NSView()
        let header = makeHeader()
        let scrollView = makeTable()
        container.addSubview(header)
        container.addSubview(scrollView)
        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            header.topAnchor.constraint(equalTo: container.topAnchor),
            header.heightAnchor.constraint(equalToConstant: 52),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        view = container
        loadDirectory()
    }

    deinit {
        loadTask?.cancel()
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        entries.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let identifier = tableColumn?.identifier, entries.indices.contains(row) else { return nil }
        let entry = entries[row]
        let value: String
        let alignment: NSTextAlignment
        switch identifier.rawValue {
        case "name":
            value = entry.isDirectory ? "▸ \(entry.name)" : entry.name
            alignment = .left
        case "kind":
            value = entry.kind
            alignment = .left
        case "size":
            value = entry.size
            alignment = .right
        default:
            value = entry.modified
            alignment = .left
        }
        return cell(identifier: identifier, text: value, alignment: alignment)
    }

    private func makeHeader() -> NSView {
        let header = NSView()
        header.translatesAutoresizingMaskIntoConstraints = false
        summaryLabel.lineBreakMode = .byTruncatingTail
        summaryLabel.translatesAutoresizingMaskIntoConstraints = false
        progressIndicator.style = .spinning
        progressIndicator.controlSize = .small
        progressIndicator.startAnimation(nil)
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(summaryLabel)
        header.addSubview(progressIndicator)
        NSLayoutConstraint.activate([
            summaryLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
            summaryLabel.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            progressIndicator.leadingAnchor.constraint(equalTo: summaryLabel.trailingAnchor, constant: 10),
            progressIndicator.trailingAnchor.constraint(lessThanOrEqualTo: header.trailingAnchor, constant: -16),
            progressIndicator.centerYAnchor.constraint(equalTo: header.centerYAnchor)
        ])
        return header
    }

    private func makeTable() -> NSScrollView {
        addColumn(identifier: "name", title: "Name", width: 320)
        addColumn(identifier: "kind", title: "Kind", width: 180)
        addColumn(identifier: "size", title: "Size", width: 100)
        addColumn(identifier: "modified", title: "Modified", width: 180)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.rowHeight = 24
        tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.documentView = tableView
        return scrollView
    }

    private func addColumn(identifier: String, title: String, width: CGFloat) {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
        column.title = title
        column.width = width
        column.minWidth = identifier == "name" ? 140 : 80
        tableView.addTableColumn(column)
    }

    private func cell(identifier: NSUserInterfaceItemIdentifier, text: String, alignment: NSTextAlignment) -> NSView {
        if let reused = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView {
            reused.textField?.stringValue = text
            reused.textField?.alignment = alignment
            return reused
        }
        let cell = NSTableCellView()
        cell.identifier = identifier
        let label = NSTextField(labelWithString: text)
        label.alignment = alignment
        label.lineBreakMode = .byTruncatingMiddle
        label.translatesAutoresizingMaskIntoConstraints = false
        cell.textField = label
        cell.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -6),
            label.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])
        return cell
    }

    private func loadDirectory() {
        loadTask = Task { [weak self, url] in
            do {
                let snapshot = try await DirectoryReader.read(url)
                try Task.checkCancellation()
                self?.show(snapshot)
            } catch is CancellationError {
                return
            } catch {
                self?.show(error)
            }
        }
    }

    private func show(_ snapshot: DirectorySnapshot) {
        entries = snapshot.entries
        progressIndicator.stopAnimation(nil)
        progressIndicator.isHidden = true
        let suffix = snapshot.isTruncated ? " · List truncated at safety limit" : ""
        summaryLabel.stringValue = "\(entries.count.formatted()) items\(suffix)"
        tableView.reloadData()
    }

    private func show(_ error: Error) {
        progressIndicator.stopAnimation(nil)
        progressIndicator.isHidden = true
        summaryLabel.stringValue = "Unable to read folder: \(error.localizedDescription)"
    }
}
