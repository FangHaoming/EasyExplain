//
//  AIExplainPopoverView.swift
//  Easydict
//
//  Created by fanghaoming on 2026/7/2.
//  Copyright © 2026 izual. All rights reserved.
//

import SFSafeSymbols
import SwiftUI

// MARK: - AIExplainPopoverView

/// SwiftUI content for the AI explanation popover. The view presents the
/// current session, renders assistant Markdown through a WebKit GFM renderer,
/// and offers a compact follow-up composer at the bottom.
struct AIExplainPopoverView: View {
    // MARK: Lifecycle

    init(queryText: String, isPinned: Binding<Bool>, onClose: @escaping () -> ()) {
        self.onClose = onClose
        self._isPinned = isPinned
        self._viewModel = StateObject(wrappedValue: AIExplainViewModel(queryText: queryText))
    }

    // MARK: Internal

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            messagesView
            Divider()
            composer
        }
        .frame(width: 560, height: 520)
        .background(Color(NSColor.windowBackgroundColor))
        .task {
            viewModel.startInitialExplain()
        }
        .onDisappear {
            viewModel.cancel()
        }
    }

    // MARK: Private

    @StateObject private var viewModel: AIExplainViewModel

    @Binding private var isPinned: Bool

    private let onClose: () -> ()

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemSymbol: .sparkles)
                .foregroundStyle(.secondary)
            Text("ai_explain.popover.title")
                .font(.headline)
            Spacer()
            Button {
                isPinned.toggle()
            } label: {
                Image(systemSymbol: isPinned ? .pinFill : .pin)
                    .foregroundStyle(isPinned ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.borderless)
            .help("pin")

            Button {
                viewModel.cancel()
                onClose()
            } label: {
                Image(systemSymbol: .xmark)
            }
            .buttonStyle(.borderless)
            .help("close")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            WindowDragArea()
        }
    }

    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 16)
                            .id("error")
                    }

                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.horizontal, 16)
                            .id("loading")
                    }
                }
                .padding(.vertical, 16)
            }
            .onChange(of: viewModel.messages.last?.id) { id in
                if let id {
                    proxy.scrollTo(id, anchor: .bottom)
                }
            }
            .onChange(of: viewModel.errorMessage) { _ in
                proxy.scrollTo("error", anchor: .bottom)
            }
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("ai_explain.input.placeholder", text: $viewModel.inputText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1 ... 4)
                .onSubmit {
                    viewModel.sendFollowUp()
                }

            if viewModel.isLoading {
                Button("cancel") {
                    viewModel.cancel()
                }
            }

            Button("ai_explain.send") {
                viewModel.sendFollowUp()
            }
            .disabled(viewModel.inputText.trim().isEmpty || viewModel.isLoading)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(16)
    }
}

// MARK: - WindowDragArea

/// AppKit bridge that lets the custom SwiftUI header drag its borderless
/// parent panel. It stays behind the title controls so buttons keep receiving
/// their normal click events.
private struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context _: Context) -> DraggableHeaderView {
        DraggableHeaderView()
    }

    func updateNSView(_: DraggableHeaderView, context _: Context) {}
}

// MARK: - DraggableHeaderView

/// Transparent header background view that delegates mouse drags to the
/// containing window. Borderless panels do not get this behavior for free.
private final class DraggableHeaderView: NSView {
    // MARK: Lifecycle

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Internal

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}

// MARK: - MessageBubble

/// Renders one message in the explanation conversation. User messages are kept
/// visually compact while assistant messages use the full Markdown renderer for
/// headings, tables, code blocks, lists, and inline formatting.
private struct MessageBubble: View {
    // MARK: Internal

    let message: AIExplainMessage

    var body: some View {
        VStack(alignment: alignment, spacing: 6) {
            Text(roleTitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            if message.role == .assistant {
                AIExplainMarkdownView(markdown: message.content, height: $assistantHeight)
                    .frame(height: assistantHeight)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(message.content)
                    .textSelection(.enabled)
                    .padding(10)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(maxWidth: .infinity, alignment: frameAlignment)
        .padding(.horizontal, 16)
    }

    // MARK: Private

    @State private var assistantHeight: CGFloat = 1

    private var alignment: HorizontalAlignment {
        message.role == .user ? .trailing : .leading
    }

    private var frameAlignment: Alignment {
        message.role == .user ? .trailing : .leading
    }

    private var roleTitle: LocalizedStringKey {
        switch message.role {
        case .system:
            "ai_explain.role.system"
        case .user:
            "ai_explain.role.user"
        case .assistant:
            "ai_explain.role.assistant"
        }
    }
}
