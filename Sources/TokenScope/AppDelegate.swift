import AppKit
import CodexUsageCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let dependencies = AppDependencies.live()
    private var window: NSWindow?
    private var statusItem: NSStatusItem?
    private var statusMenu: NSMenu?

    private var store: UsageStore {
        dependencies.store
    }

    private var preferencesStore: UserPreferencesStore {
        dependencies.preferencesStore
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let contentView = ContentView().environmentObject(store)
        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "TokenScope"
        window.setContentSize(windowSize(for: store.viewMode))
        window.minSize = Self.minimumWindowSize(for: store.viewMode)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window

        setupMenuBar()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func windowDidResize(_ notification: Notification) {
        saveCurrentWindowSize()
    }

    func windowWillClose(_ notification: Notification) {
        saveCurrentWindowSize()
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

        let contentSize = windowSize(for: viewMode)
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

    private func windowSize(for viewMode: UsageViewMode) -> NSSize {
        let minimumSize = Self.minimumWindowSize(for: viewMode)
        if let savedSize = preferencesStore.loadWindowSize(for: viewMode) {
            return NSSize(
                width: max(savedSize.width, minimumSize.width),
                height: max(savedSize.height, minimumSize.height)
            )
        }

        return Self.defaultWindowSize(for: viewMode)
    }

    private static func defaultWindowSize(for viewMode: UsageViewMode) -> NSSize {
        switch viewMode {
        case .simple:
            return NSSize(width: 960, height: 560)
        case .detailed:
            return NSSize(width: 1_180, height: 820)
        }
    }

    private static func minimumWindowSize(for viewMode: UsageViewMode) -> NSSize {
        switch viewMode {
        case .simple:
            return NSSize(width: 900, height: 500)
        case .detailed:
            return NSSize(width: 1_080, height: 680)
        }
    }

    private func saveCurrentWindowSize() {
        guard let window else {
            return
        }

        let contentSize = window.contentRect(forFrameRect: window.frame).size
        preferencesStore.saveWindowSize(contentSize, for: store.viewMode)
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
