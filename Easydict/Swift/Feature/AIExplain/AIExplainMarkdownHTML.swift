//
//  AIExplainMarkdownHTML.swift
//  Easydict
//
//  Created by fanghaoming on 2026/7/2.
//  Copyright © 2026 izual. All rights reserved.
//

import SwiftUI

// MARK: - AIExplainMarkdownHTML

/// Builds the self-contained HTML shell used by the AI explanation popover.
/// Markdown parsing is delegated to bundled `marked.umd.js`, so rendering is
/// broad, offline-capable, and independent of SwiftUI's Markdown subset.
struct AIExplainMarkdownHTML {
    // MARK: Internal

    let markdown: String
    let colorScheme: ColorScheme

    func makeDocument() -> String {
        let labelColor = colorScheme == .dark ? "#f5f5f7" : "#1f2328"
        let secondaryColor = colorScheme == .dark ? "#a1a1aa" : "#59636e"
        let borderColor = colorScheme == .dark ? "#3f3f46" : "#d0d7de"
        let codeBackground = colorScheme == .dark ? "#27272a" : "#f6f8fa"
        let tableHeader = colorScheme == .dark ? "#2f3037" : "#f6f8fa"
        let markdownJSON = jsonString(markdown)

        return """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <style>
            :root {
              color-scheme: \(colorScheme == .dark ? "dark" : "light");
              --text: \(labelColor);
              --secondary: \(secondaryColor);
              --border: \(borderColor);
              --code-bg: \(codeBackground);
              --table-header: \(tableHeader);
              --link: #0a84ff;
            }
            * { box-sizing: border-box; }
            html, body {
              margin: 0;
              padding: 0;
              background: transparent;
              color: var(--text);
              font: 13px/1.48 -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
              letter-spacing: 0;
              overflow: hidden;
            }
            body { -webkit-font-smoothing: antialiased; }
            #content > :first-child { margin-top: 0; }
            #content > :last-child { margin-bottom: 0; }
            p { margin: 0 0 10px; }
            h1, h2, h3, h4, h5, h6 {
              margin: 16px 0 8px;
              font-weight: 700;
              line-height: 1.25;
            }
            h1 { font-size: 21px; }
            h2 { font-size: 18px; }
            h3 { font-size: 16px; }
            h4, h5, h6 { font-size: 14px; }
            ul, ol { margin: 0 0 10px; padding-left: 24px; }
            li { margin: 3px 0; }
            li > p { margin: 4px 0; }
            blockquote {
              margin: 0 0 10px;
              padding: 0 0 0 12px;
              color: var(--secondary);
              border-left: 3px solid var(--border);
            }
            pre {
              margin: 0 0 12px;
              padding: 10px 12px;
              overflow-x: auto;
              border: 1px solid var(--border);
              border-radius: 6px;
              background: var(--code-bg);
            }
            code {
              padding: 0.1em 0.35em;
              border-radius: 4px;
              background: var(--code-bg);
              font-family: "SF Mono", Menlo, Consolas, monospace;
              font-size: 0.92em;
            }
            pre code {
              padding: 0;
              border-radius: 0;
              background: transparent;
              white-space: pre;
            }
            table {
              width: 100%;
              margin: 0 0 12px;
              border-spacing: 0;
              border-collapse: collapse;
              font-size: 12px;
            }
            th, td {
              padding: 6px 8px;
              border: 1px solid var(--border);
              vertical-align: top;
            }
            th { background: var(--table-header); font-weight: 600; }
            a { color: var(--link); text-decoration: none; }
            a:hover { text-decoration: underline; }
            hr {
              height: 1px;
              margin: 16px 0;
              border: 0;
              background: var(--border);
            }
            img { max-width: 100%; height: auto; }
            input[type="checkbox"] { margin-right: 6px; }
            .fallback {
              margin: 0;
              white-space: pre-wrap;
              font-family: inherit;
            }
          </style>
          <script src="marked.umd.js"></script>
        </head>
        <body>
          <main id="content"></main>
          <script>
            const source = \(markdownJSON);
            const content = document.getElementById("content");

            function sanitize(root) {
              root.querySelectorAll("script, style, iframe, object, embed, link, meta").forEach(
                node => node.remove()
              );
              root.querySelectorAll("*").forEach(element => {
                [...element.attributes].forEach(attribute => {
                  const name = attribute.name.toLowerCase();
                  const value = attribute.value.trim().toLowerCase();
                  if (name.startsWith("on") || value.startsWith("javascript:")) {
                    element.removeAttribute(attribute.name);
                  }
                });
                if (element.tagName === "A") {
                  element.setAttribute("rel", "noreferrer noopener");
                }
              });
            }

            function reportHeight() {
              requestAnimationFrame(() => {
                const height = Math.ceil(Math.max(
                  document.body.scrollHeight,
                  document.documentElement.scrollHeight
                ));
                window.webkit.messageHandlers.height.postMessage(height);
              });
            }

            function renderFallback() {
              const fallback = document.createElement("pre");
              fallback.className = "fallback";
              fallback.textContent = source;
              content.replaceChildren(fallback);
              reportHeight();
            }

            function renderMarkdown() {
              if (!window.marked) {
                renderFallback();
                return;
              }

              marked.setOptions({ gfm: true, breaks: true });
              const template = document.createElement("template");
              template.innerHTML = marked.parse(source);
              sanitize(template.content);
              content.replaceChildren(template.content.cloneNode(true));
              reportHeight();
            }

            window.addEventListener("load", renderMarkdown);
          </script>
        </body>
        </html>
        """
    }

    // MARK: Private

    private func jsonString(_ value: String) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let encoded = String(data: data, encoding: .utf8)
        else {
            return "\"\""
        }

        return encoded.replacingOccurrences(of: "</", with: "<\\/")
    }
}
