import AppKit
@preconcurrency import CoreGraphics

// Filters Finder's Space key and routes it to the custom preview lifecycle.
@MainActor
final class GlobalKeyMonitor {
    private static let forwardedEventMarker: Int64 = 0x53504143454C4F4F
    private let isPreviewVisible: () -> Bool
    private let onSpace: () -> Void
    private let onEscape: () -> Void
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var capturesSpace = false

    init(isPreviewVisible: @escaping () -> Bool, onSpace: @escaping () -> Void, onEscape: @escaping () -> Void) {
        self.isPreviewVisible = isPreviewVisible
        self.onSpace = onSpace
        self.onEscape = onEscape
    }

    func start() -> Bool {
        guard eventTap == nil else { return true }
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
            | CGEventMask(1 << CGEventType.keyUp.rawValue)
            | CGEventMask(1 << CGEventType.tapDisabledByTimeout.rawValue)
            | CGEventMask(1 << CGEventType.tapDisabledByUserInput.rawValue)
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<GlobalKeyMonitor>.fromOpaque(userInfo).takeUnretainedValue()
                return MainActor.assumeIsolated { monitor.handle(type: type, event: event) }
            },
            userInfo: pointer
        ) else { return false }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        eventTap = tap
        runLoopSource = source
        return true
    }

    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: false) }
        runLoopSource = nil
        eventTap = nil
    }

    func passSpaceToSystem() {
        for keyDown in [true, false] {
            guard let event = CGEvent(keyboardEventSource: nil, virtualKey: 49, keyDown: keyDown) else { continue }
            event.setIntegerValueField(.eventSourceUserData, value: Self.forwardedEventMarker)
            event.post(tap: .cgSessionEventTap)
        }
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        if event.getIntegerValueField(.eventSourceUserData) == Self.forwardedEventMarker {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        if keyCode == 53, type == .keyDown, isPreviewVisible() {
            onEscape()
            return nil
        }
        guard keyCode == 49 else { return Unmanaged.passUnretained(event) }

        if type == .keyDown {
            let forbidden: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate]
            let finderIsActive = NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.finder"
            capturesSpace = event.flags.intersection(forbidden).isEmpty && (finderIsActive || isPreviewVisible())
            if capturesSpace { onSpace(); return nil }
        } else if type == .keyUp, capturesSpace {
            capturesSpace = false
            return nil
        }
        return Unmanaged.passUnretained(event)
    }
}
