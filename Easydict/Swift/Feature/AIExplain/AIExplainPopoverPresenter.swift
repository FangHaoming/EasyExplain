//
//  AIExplainPopoverPresenter.swift
//  Easydict
//
//  Created by fanghaoming on 2026/7/2.
//  Copyright © 2026 izual. All rights reserved.
//

import AppKit
import SwiftUI

// MARK: - AIExplainPanel

/// Borderless floating panel that still accepts keyboard focus. The AI
/// explanation UI needs a custom chrome but must keep TextField editing and
/// close-button clicks on the normal window path.
private final class AIExplainPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - AIExplainPopoverPresenter

/// Bridges the Objective-C title bar button and global shortcut to a SwiftUI
/// explanation panel. A lightweight `NSPanel` is used instead of `NSPopover`
/// so WebKit teardown cannot block closing the conversation UI.
@objcMembers
final class AIExplainPopoverPresenter: NSObject {
    // MARK: Lifecycle

    private override init() {
        super.init()
        EventMonitor.shared.shouldKeepFloatingWindowBlock = { [weak self] point in
            self?.containsPopover(at: point) == true
        }
    }

    // MARK: Internal

    static let shared = AIExplainPopoverPresenter()

    func toggleCurrentQueryWindow() {
        guard MyConfiguration.shared.enableAIExplain else {
            return
        }

        guard let window = EZWindowManager.shared().floatingWindow else {
            return
        }

        let titleBar = window.titleBar
        let anchorView: NSView = titleBar.explainButton.superview == nil
            ? titleBar
            : titleBar.explainButton
        let queryText = window.queryViewController.queryModel.queryText ?? ""
        toggle(anchorView: anchorView, queryText: queryText)
    }

    func explainSelectedText() {
        guard MyConfiguration.shared.enableAIExplain else {
            return
        }

        if Screenshot.shared.isTakingScreenshot {
            return
        }

        EventMonitor.shared.actionType = .shortcutQuery
        EventMonitor.shared.getSelectedTextWithCompletion { [weak self] text in
            let queryText = text?.trim() ?? ""
            DispatchQueue.main.async {
                guard !queryText.isEmpty else {
                    return
                }
                self?.showStandalone(queryText: queryText)
            }
        }
    }

    func toggle(anchorView: NSView, queryText: String) {
        if Date() < suppressToggleUntil {
            return
        }

        if panel?.isVisible == true {
            close()
            return
        }

        show(anchorView: anchorView, queryText: queryText)
    }

    func close() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.close()
            }
            return
        }

        guard !isClosing else {
            return
        }

        isClosing = true
        let closingPanel = panel
        panel = nil
        removeMouseMonitors()
        closingPanel?.orderOut(nil)
        closingPanel?.close()

        DispatchQueue.main.async { [weak self] in
            self?.isClosing = false
        }
    }

    func containsPopover(at point: CGPoint) -> Bool {
        guard let panel, panel.isVisible else {
            return false
        }

        return panel.windowNumber == NSWindow.windowNumber(at: point, belowWindowWithWindowNumber: 0)
    }

    func containsMouseLocation() -> Bool {
        containsPopover(at: NSEvent.mouseLocation)
    }

    // MARK: Private

    private let panelSize = NSSize(width: 560, height: 520)

    private var panel: NSPanel?
    private var isPinned = false
    private var isClosing = false
    private var localMouseMonitor: Any?
    private var globalMouseMonitor: Any?
    private var suppressToggleUntil = Date.distantPast

    private func showStandalone(queryText: String) {
        if panel?.isVisible == true {
            close()
        }

        NSApplication.shared.activateApp()
        showPanel(queryText: queryText, origin: standaloneOrigin())
    }

    private func show(anchorView: NSView, queryText: String) {
        NSApplication.shared.activateApp()
        showPanel(queryText: queryText, origin: anchoredOrigin(for: anchorView))
    }

    private func showPanel(queryText: String, origin: NSPoint) {
        isPinned = false
        let panel = AIExplainPanel(
            contentRect: NSRect(origin: origin, size: panelSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = NSWindow.Level(Int(CGWindowLevelForKey(.modalPanelWindow)) + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.contentViewController = NSHostingController(
            rootView: AIExplainPopoverView(
                queryText: queryText,
                isPinned: Binding(
                    get: { [weak self] in self?.isPinned == true },
                    set: { [weak self] value in self?.isPinned = value }
                )
            ) { [weak self] in
                self?.close()
            }
        )

        self.panel = panel
        panel.orderFrontRegardless()
        installMouseMonitors()
    }

    private func installMouseMonitors() {
        removeMouseMonitors()

        localMouseMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            self?.closeIfNeeded(for: event)
            return event
        }

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            self?.closeIfNeeded(for: event)
        }
    }

    private func removeMouseMonitors() {
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
            self.localMouseMonitor = nil
        }

        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
            self.globalMouseMonitor = nil
        }
    }

    private func closeIfNeeded(for event: NSEvent) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.closeIfNeeded(for: event)
            }
            return
        }

        guard !isPinned, let panel, panel.isVisible else {
            return
        }

        let eventPoint = screenPoint(for: event)
        if !panel.frame.contains(eventPoint) {
            suppressToggleUntil = Date().addingTimeInterval(0.2)
            close()
        }
    }

    private func screenPoint(for event: NSEvent) -> NSPoint {
        guard let window = event.window else {
            return NSEvent.mouseLocation
        }

        let rect = NSRect(origin: event.locationInWindow, size: .zero)
        return window.convertToScreen(rect).origin
    }

    private func anchoredOrigin(for anchorView: NSView) -> NSPoint {
        guard let anchorWindow = anchorView.window else {
            return standaloneOrigin()
        }

        let visibleFrame = (anchorWindow.screen ?? NSScreen.main)?.visibleFrame ?? .zero
        let anchorFrame = anchorWindow.frame
        let gap: CGFloat = 8
        let centeredY = anchorFrame.midY - panelSize.height / 2
        let leftOrigin = NSPoint(
            x: anchorFrame.minX - panelSize.width - gap,
            y: centeredY
        )
        let rightOrigin = NSPoint(
            x: anchorFrame.maxX + gap,
            y: centeredY
        )

        if leftOrigin.x >= visibleFrame.minX + 12 {
            return clampedOrigin(leftOrigin, preferredScreen: anchorWindow.screen)
        }
        if rightOrigin.x + panelSize.width <= visibleFrame.maxX - 12 {
            return clampedOrigin(rightOrigin, preferredScreen: anchorWindow.screen)
        }

        let overlayOrigin = NSPoint(
            x: anchorFrame.maxX - panelSize.width - 16,
            y: anchorFrame.maxY - panelSize.height - 16
        )
        return clampedOrigin(overlayOrigin, preferredScreen: anchorWindow.screen)
    }

    private func standaloneOrigin() -> NSPoint {
        let mouseLocation = NSEvent.mouseLocation
        let origin = NSPoint(
            x: mouseLocation.x - panelSize.width / 2,
            y: mouseLocation.y - panelSize.height - 12
        )
        let screen = NSScreen.screens.first { $0.visibleFrame.contains(mouseLocation) }
        return clampedOrigin(origin, preferredScreen: screen)
    }

    private func clampedOrigin(_ origin: NSPoint, preferredScreen: NSScreen?) -> NSPoint {
        let visibleFrame = (preferredScreen ?? NSScreen.main)?.visibleFrame ?? .zero
        return NSPoint(
            x: min(max(origin.x, visibleFrame.minX + 12), visibleFrame.maxX - panelSize.width - 12),
            y: min(max(origin.y, visibleFrame.minY + 12), visibleFrame.maxY - panelSize.height - 12)
        )
    }
}
