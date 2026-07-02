//
//  AIExplainClient.swift
//  Easydict
//
//  Created by fanghaoming on 2026/7/2.
//  Copyright © 2026 izual. All rights reserved.
//

import Foundation

// MARK: - AIExplainClient

/// Streams explanation content from OpenAI-compatible or Anthropic-compatible
/// chat APIs. The client owns only the active network task so the popover can
/// cancel work immediately when it closes or starts a new turn.
final class AIExplainClient {
    // MARK: Internal

    func streamExplain(
        text: String,
        messages: [AIExplainMessage],
        configuration: AIExplainConfiguration
    )
        -> AsyncThrowingStream<String, Error> {
        do {
            try validate(configuration: configuration)
        } catch {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: error)
            }
        }

        switch configuration.provider {
        case .openAICompatible:
            return openAIStream(text: text, messages: messages, configuration: configuration)
        case .anthropicCompatible:
            return anthropicStream(text: text, messages: messages, configuration: configuration)
        }
    }

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
    }

    // MARK: Private

    private let anthropicVersion = "2023-06-01"
    private let maxTokens = 4096
    private var currentTask: Task<(), Never>?

    private func openAIStream(
        text: String,
        messages: [AIExplainMessage],
        configuration: AIExplainConfiguration
    )
        -> AsyncThrowingStream<String, Error> {
        requestStream(
            request: openAIRequest(
                text: text,
                messages: messages,
                configuration: configuration
            ),
            parser: parseOpenAIEvent(_:)
        )
    }

    private func anthropicStream(
        text: String,
        messages: [AIExplainMessage],
        configuration: AIExplainConfiguration
    )
        -> AsyncThrowingStream<String, Error> {
        requestStream(
            request: anthropicRequest(
                text: text,
                messages: messages,
                configuration: configuration
            ),
            parser: parseAnthropicEvent(_:)
        )
    }

    private func validate(configuration: AIExplainConfiguration) throws {
        guard URL(string: configuration.endpoint)?.isValid == true else {
            throw QueryError(
                type: .parameter,
                message: String(localized: "ai_explain.error.invalid_api_url")
            )
        }
        guard !configuration.apiKey.isEmpty else {
            throw QueryError(
                type: .missingSecretKey,
                message: String(localized: "ai_explain.error.empty_api_key")
            )
        }
        guard !configuration.model.isEmpty else {
            throw QueryError(
                type: .parameter,
                message: String(localized: "ai_explain.error.empty_model")
            )
        }
    }

    private func requestStream(
        request: URLRequest,
        parser: @escaping (String) throws -> String?
    )
        -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            cancel()

            let task = Task {
                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    try await validateHTTPResponse(response, bytes: bytes)

                    for try await line in bytes.lines {
                        try Task.checkCancellation()
                        guard let event = eventPayload(from: line) else { continue }
                        if event == "[DONE]" { break }
                        if let content = try parser(event), !content.isEmpty {
                            continuation.yield(content)
                        }
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            currentTask = task
            continuation.onTermination = { [weak self] _ in
                task.cancel()
                self?.currentTask = nil
            }
        }
    }

    private func validateHTTPResponse(
        _ response: URLResponse,
        bytes: URLSession.AsyncBytes
    ) async throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw QueryError(type: .api, message: String(localized: "ai_explain.error.invalid_response"))
        }
        guard !(200 ... 299).contains(httpResponse.statusCode) else { return }

        let errorData = try await bytes.prefix(4096).reduce(into: Data()) { $0.append($1) }
        let body = String(data: errorData, encoding: .utf8)?.trim()
        let message = body?.isEmpty == false
            ? body!
            : String(format: String(localized: "ai_explain.error.http_status"), httpResponse.statusCode)
        throw QueryError(type: .api, message: message)
    }

    private func eventPayload(from line: String) -> String? {
        guard line.hasPrefix("data:") else { return nil }
        return String(line.dropFirst(5)).trim()
    }

    private func openAIRequest(
        text: String,
        messages: [AIExplainMessage],
        configuration: AIExplainConfiguration
    )
        -> URLRequest {
        let requestMessages = openAIMessages(
            text: text,
            messages: messages,
            configuration: configuration
        )
        let body: [String: Any] = [
            "model": configuration.model,
            "stream": true,
            "messages": requestMessages,
        ]

        var request = URLRequest(url: URL(string: configuration.endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(configuration.apiKey, forHTTPHeaderField: "api-key")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func anthropicRequest(
        text: String,
        messages: [AIExplainMessage],
        configuration: AIExplainConfiguration
    )
        -> URLRequest {
        let systemPrompt = systemPrompt(for: configuration)
        let requestMessages = anthropicMessages(
            text: text,
            messages: messages,
            configuration: configuration
        )

        var body: [String: Any] = [
            "model": configuration.model,
            "max_tokens": maxTokens,
            "stream": true,
            "messages": requestMessages,
        ]
        if !systemPrompt.isEmpty {
            body["system"] = systemPrompt
        }

        var request = URLRequest(url: URL(string: configuration.endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(configuration.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(anthropicVersion, forHTTPHeaderField: "anthropic-version")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func openAIMessages(
        text: String,
        messages: [AIExplainMessage],
        configuration: AIExplainConfiguration
    )
        -> [[String: String]] {
        var requestMessages: [[String: String]] = []
        let systemPrompt = systemPrompt(for: configuration)
        if !systemPrompt.isEmpty {
            requestMessages.append([
                "role": AIExplainMessage.Role.system.rawValue,
                "content": systemPrompt,
            ])
        }
        requestMessages.append(contentsOf: visibleMessages(
            text: text,
            messages: messages,
            configuration: configuration
        ).map {
            ["role": $0.role.rawValue, "content": $0.content]
        })
        return requestMessages
    }

    private func anthropicMessages(
        text: String,
        messages: [AIExplainMessage],
        configuration: AIExplainConfiguration
    )
        -> [[String: String]] {
        visibleMessages(text: text, messages: messages, configuration: configuration).compactMap { message in
            switch message.role {
            case .system:
                nil
            case .user:
                ["role": "user", "content": message.content]
            case .assistant:
                ["role": "assistant", "content": message.content]
            }
        }
    }

    private func visibleMessages(
        text: String,
        messages: [AIExplainMessage],
        configuration: AIExplainConfiguration
    )
        -> [AIExplainMessage] {
        if messages.isEmpty {
            return [.init(role: .user, content: configuration.outputLanguage.initialPrompt(for: text))]
        }
        return messages
    }

    private func systemPrompt(for configuration: AIExplainConfiguration) -> String {
        [
            configuration.systemPrompt,
            configuration.outputLanguage.responseInstruction,
        ]
        .map { $0.trim() }
        .filter { !$0.isEmpty }
        .joined(separator: "\n\n")
    }

    private func parseOpenAIEvent(_ event: String) throws -> String? {
        guard let data = event.data(using: .utf8),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = object["choices"] as? [[String: Any]],
              let delta = choices.first?["delta"] as? [String: Any]
        else {
            return nil
        }
        return delta["content"] as? String
    }

    private func parseAnthropicEvent(_ event: String) throws -> String? {
        guard let data = event.data(using: .utf8),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["type"] as? String == "content_block_delta",
              let delta = object["delta"] as? [String: Any],
              delta["type"] as? String == "text_delta"
        else {
            return nil
        }
        return delta["text"] as? String
    }
}
