import AppKit
import SwiftUI

// Runs SpaceLook as a menu bar utility without a persistent application window.
@main
struct SpaceLookApp: App {
    @NSApplicationDelegateAdaptor(AppCoordinator.self) private var appCoordinator

    var body: some Scene {
        MenuBarExtra("SpaceLook", image: "MenuBarIcon") {
            Button("Quit SpaceLook") {
                NSApp.terminate(nil)
            }
        }
        .menuBarExtraStyle(.menu)
    }
}
