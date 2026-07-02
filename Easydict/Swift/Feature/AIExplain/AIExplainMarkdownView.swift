//
//  AIExplainMarkdownView.swift
//  Easydict
//
//  Created by fanghaoming on 2026/7/2.
//  Copyright © 2026 izual. All rights reserved.
//

import AppKit
import SwiftUI
@preconcurrency import WebKit

// MARK: - AIExplainMarkdownWebView

/// Non-scrolling Markdown web view used inside the popover's SwiftUI scroll
/// view. Vertical wheel events are forwarded so the outer conversation view
/// scrolls even when the pointer is over rendered Markdown content.
private final class AIExplainMarkdownWebView: WKWebView {
    override func scrollWheel(with event: NSEvent) {
        if abs(event.scrollingDeltaY) >= abs(event.scrollingDeltaX) {
            nextResponder?.scrollWheel(with: event)
        } else {
            super.scrollWheel(with: event)
        }
    }
}

// MARK: - AIExplainMarkdownView

/// SwiftUI wrapper around a non-scrolling `WKWebView` for assistant Markdown.
/// The view renders common GitHub-flavored Markdown blocks and reports its
/// document height so it can live inside the popover's SwiftUI scroll view.
struct AIExplainMarkdownView: NSViewRepresentable {
    // MARK: Internal

    // MARK: - Coordinator

    /// Debounces streaming Markdown updates and keeps WebKit navigation inside
    /// the popover from replacing the rendered explanation.
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        // MARK: Lifecycle

        init(parent: AIExplainMarkdownView) {
            self.parent = parent
        }

        // MARK: Internal

        var parent: AIExplainMarkdownView

        func cancelPendingRender() {
            pendingRender?.cancel()
            pendingRender = nil
        }

        func scheduleRender(in webView: WKWebView) {
            guard parent.markdown != renderedMarkdown || parent.colorScheme != renderedColorScheme else {
                refreshHeight(in: webView)
                return
            }

            pendingRender?.cancel()
            let workItem = DispatchWorkItem { [weak self, weak webView] in
                guard let self, let webView else { return }
                renderedMarkdown = parent.markdown
                renderedColorScheme = parent.colorScheme
                webView.loadHTMLString(parent.html, baseURL: Bundle.main.resourceURL)
            }
            pendingRender = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: workItem)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> ()
        ) {
            guard navigationAction.navigationType == .linkActivated,
                  let url = navigationAction.request.url
            else {
                decisionHandler(.allow)
                return
            }

            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            refreshHeight(in: webView)
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == "height", let value = message.body as? NSNumber else {
                return
            }

            parent.height = max(1, CGFloat(value.doubleValue))
        }

        // MARK: Private

        private var pendingRender: DispatchWorkItem?
        private var renderedMarkdown = ""
        private var renderedColorScheme: ColorScheme?

        private func refreshHeight(in webView: WKWebView) {
            webView.evaluateJavaScript(
                "Math.ceil(Math.max(document.body.scrollHeight, document.documentElement.scrollHeight))"
            ) { [weak self] result, _ in
                guard let self else { return }
                if let number = result as? NSNumber {
                    parent.height = max(1, CGFloat(number.doubleValue))
                }
            }
        }
    }

    let markdown: String

    @Binding var height: CGFloat

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.cancelPendingRender()
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "height")
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.userContentController.add(context.coordinator, name: "height")

        let webView = AIExplainMarkdownWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.scheduleRender(in: webView)
    }

    // MARK: Private

    @Environment(\.colorScheme) private var colorScheme

    private var html: String {
        AIExplainMarkdownHTML(markdown: markdown, colorScheme: colorScheme)
            .makeDocument()
    }
}
