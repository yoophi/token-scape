import AppKit
import CodexUsageCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = UsageStore()
    private var window: NSWindow?
    private var statusItem: NSStatusItem?
    private var statusMenu: NSMenu?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let contentView = ContentView().environmentObject(store)
        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "AI Code Usage Viewer"
        window.setContentSize(Self.windowSize(for: store.viewMode))
        window.minSize = Self.minimumWindowSize(for: store.viewMode)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window

        setupMenuBar()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func setupMenuBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(toggleWindow)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "열기", action: #selector(showWindow), keyEquivalent: "o"))
        menu.addItem(NSMenuItem(title: "새로고침", action: #selector(refresh), keyEquivalent: "r"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "종료", action: #selector(quit), keyEquivalent: "q"))
        statusMenu = menu

        store.onCodexChange = { [weak self] snapshot in
            self?.updateStatusTitle(snapshot)
        }
        store.onAlwaysOnTopChange = { [weak self] isAlwaysOnTop in
            self?.setAlwaysOnTop(isAlwaysOnTop)
        }
        store.onViewModeChange = { [weak self] viewMode in
            self?.resizeWindow(for: viewMode)
        }
        setAlwaysOnTop(store.isAlwaysOnTop)
        updateStatusTitle(store.codexSnapshot)
    }

    private func resizeWindow(for viewMode: UsageViewMode) {
        guard let window else {
            return
        }

        let contentSize = Self.windowSize(for: viewMode)
        let currentFrame = window.frame
        let newFrame = NSRect(
            x: currentFrame.midX - contentSize.width / 2,
            y: currentFrame.midY - contentSize.height / 2,
            width: contentSize.width,
            height: contentSize.height
        )

        window.minSize = Self.minimumWindowSize(for: viewMode)
        window.setFrame(newFrame, display: true, animate: true)
    }

    private func setAlwaysOnTop(_ isAlwaysOnTop: Bool) {
        window?.level = isAlwaysOnTop ? .floating : .normal
    }

    private static func windowSize(for viewMode: UsageViewMode) -> NSSize {
        switch viewMode {
        case .simple:
            return NSSize(width: 1_060, height: 610)
        case .detailed:
            return NSSize(width: 1_180, height: 820)
        }
    }

    private static func minimumWindowSize(for viewMode: UsageViewMode) -> NSSize {
        switch viewMode {
        case .simple:
            return NSSize(width: 920, height: 520)
        case .detailed:
            return NSSize(width: 980, height: 680)
        }
    }

    private func updateStatusTitle(_ snapshot: UsageSnapshot?) {
        let remainingValues = [snapshot?.primary?.remainingPercent, snapshot?.secondary?.remainingPercent].compactMap { $0 }
        if let remaining = remainingValues.min() {
            statusItem?.button?.title = "Codex \(Int(remaining.rounded()))%"
        } else {
            statusItem?.button?.title = "Usage"
        }
    }

    @objc private func toggleWindow() {
        guard let event = NSApp.currentEvent, event.type == .rightMouseUp else {
            showWindow()
            return
        }
        guard let button = statusItem?.button else {
            return
        }
        statusMenu?.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    @objc private func showWindow() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func refresh() {
        store.refresh()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
