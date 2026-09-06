import AppKit
import ServiceManagement
import os

@main
struct FreeBarApp {
    @MainActor
    static func main() {
        // Maintenance entry point used by uninstall.sh, not a second app instance.
        if CommandLine.arguments.contains("--unregister-login") {
            do {
                if SMAppService.mainApp.status == .enabled || SMAppService.mainApp.status == .requiresApproval {
                    try SMAppService.mainApp.unregister()
                }
                return
            } catch {
                fputs("FreeBar: cannot unregister Launch at Login: \(error.localizedDescription)\n", stderr)
                exit(1)
            }
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private let monitor = StorageMonitor()
    private let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLogin), keyEquivalent: "")
    private let logger = Logger(subsystem: "com.alessandroviola.freebar", category: "Login")
    private var loginError: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Launch Services normally reuses the running instance; also guard direct runs.
        if NSRunningApplication.runningApplications(withBundleIdentifier: "com.alessandroviola.freebar")
            .contains(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier && !$0.isTerminated }) {
            NSApp.terminate(nil)
            return
        }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item
        item.button?.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        item.button?.title = "Mac ?"
        item.button?.setAccessibilityLabel("FreeBar: Mac storage unavailable")
        let menu = NSMenu()
        menu.delegate = self
        let refresh = NSMenuItem(title: "Refresh", action: #selector(refreshStorage), keyEquivalent: "")
        refresh.target = self
        menu.addItem(refresh)
        loginItem.target = self
        menu.addItem(loginItem)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit FreeBar", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        item.menu = menu
        monitor.onChange = { [weak self] title in
            self?.statusItem?.button?.title = title
            self?.statusItem?.button?.setAccessibilityLabel("FreeBar available storage: " + title)
        }
        monitor.start()
    }

    func menuWillOpen(_ menu: NSMenu) { updateLoginState() }

    private func updateLoginState() {
        switch SMAppService.mainApp.status {
        case .enabled:
            loginItem.state = .on
            loginItem.toolTip = nil
        case .requiresApproval:
            loginItem.state = .mixed
            loginItem.toolTip = "Awaiting approval in System Settings → General → Login Items. Click to disable."
        default:
            loginItem.state = .off
            loginItem.toolTip = nil
        }
        if let loginError { loginItem.toolTip = loginError }
    }

    @objc private func toggleLogin() {
        loginError = nil
        do {
            let status = SMAppService.mainApp.status
            if status == .enabled || status == .requiresApproval {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
                if SMAppService.mainApp.status == .requiresApproval {
                    SMAppService.openSystemSettingsLoginItems()
                }
            }
            updateLoginState()
        } catch {
            logger.error("Launch at Login change failed: \(error.localizedDescription, privacy: .public)")
            // Retain the explanation when the menu is reopened, until the next attempt.
            loginError = "Could not change Launch at Login: " + error.localizedDescription
            updateLoginState()
            NSSound.beep()
        }
    }

    @objc private func refreshStorage() { monitor.refresh() }
    @objc private func quitApp() { NSApp.terminate(nil) }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
        if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
        statusItem = nil
    }
}
