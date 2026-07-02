//
//  AIExplainViewModel.swift
//  Easydict
//
//  Created by fanghaoming on 2026/7/2.
//  Copyright © 2026 izual. All rights reserved.
//

import Foundation

// MARK: - AIExplainViewModel

/// Coordinates the explanation popover state for one query text. It owns the
/// in-memory conversation, starts the first explanation automatically, and
/// cancels outstanding network work when the user closes the popover.
@MainActor
final class AIExplainViewModel: ObservableObject {
    // MARK: Lifecycle

    init(queryText: String, client: AIExplainClient = AIExplainClient()) {
        self.queryText = queryText.trim()
        self.client = client
    }

    // MARK: Internal

    @Published private(set) var messages: [AIExplainMessage] = []
    @Published var inputText = ""
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    func startInitialExplain() {
        guard messages.isEmpty else { return }
        guard !queryText.isEmpty else {
            errorMessage = String(localized: "ai_explain.error.empty_query")
            return
        }

        let userMessage = AIExplainMessage(role: .user, content: initialPrompt)
        messages.append(userMessage)
        startRequest()
    }

    func sendFollowUp() {
        let prompt = inputText.trim()
        guard !prompt.isEmpty, !isLoading else { return }
        inputText = ""
        messages.append(.init(role: .user, content: prompt))
        startRequest()
    }

    func cancel() {
        client.cancel()
        requestTask?.cancel()
        requestTask = nil
        pendingAppendTask?.cancel()
        pendingAppendTask = nil
        pendingContent = ""
        isLoading = false
    }

    // MARK: Private

    private let queryText: String
    private let client: AIExplainClient
    private var requestTask: Task<(), Never>?
    private var pendingAppendTask: Task<(), Never>?
    private var pendingContent = ""

    private var initialPrompt: String {
        AIExplainConfiguration.current.outputLanguage.initialPrompt(for: queryText)
    }

    private func startRequest() {
        cancel()
        isLoading = true
        errorMessage = nil
        messages.append(.init(role: .assistant, content: ""))
        let assistantID = messages.last?.id
        let requestMessages = messages.filter { !($0.role == .assistant && $0.id == assistantID) }
        let configuration = AIExplainConfiguration.current

        requestTask = Task { [weak self] in
            guard let self else { return }

            do {
                let stream = client.streamExplain(
                    text: queryText,
                    messages: requestMessages,
                    configuration: configuration
                )
                for try await content in stream {
                    try Task.checkCancellation()
                    scheduleAppend(content: content, to: assistantID)
                }
                flushPendingContent(to: assistantID)
                isLoading = false
                removeEmptyAssistantIfNeeded(assistantID)
            } catch is CancellationError {
                flushPendingContent(to: assistantID)
                isLoading = false
                removeEmptyAssistantIfNeeded(assistantID)
            } catch {
                flushPendingContent(to: assistantID)
                isLoading = false
                removeEmptyAssistantIfNeeded(assistantID)
                errorMessage = QueryError.queryError(from: error)?.localizedDescription
                    ?? error.localizedDescription
            }
        }
    }

    private func scheduleAppend(content: String, to assistantID: UUID?) {
        pendingContent += content
        guard pendingAppendTask == nil else { return }

        pendingAppendTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 80_000_000)
            guard !Task.isCancelled else { return }
            await self?.flushPendingContent(to: assistantID)
        }
    }

    private func flushPendingContent(to assistantID: UUID?) {
        pendingAppendTask?.cancel()
        pendingAppendTask = nil

        guard !pendingContent.isEmpty else { return }
        let content = pendingContent
        pendingContent = ""
        append(content: content, to: assistantID)
    }

    private func append(content: String, to assistantID: UUID?) {
        guard let assistantID,
              let index = messages.firstIndex(where: { $0.id == assistantID })
        else { return }

        messages[index].content += content
    }

    private func removeEmptyAssistantIfNeeded(_ assistantID: UUID?) {
        guard let assistantID,
              let index = messages.firstIndex(where: { $0.id == assistantID }),
              messages[index].content.trim().isEmpty
        else { return }

        messages.remove(at: index)
    }
}
