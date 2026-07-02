//
//  AIExplainProvider.swift
//  Easydict
//
//  Created by fanghaoming on 2026/7/2.
//  Copyright © 2026 izual. All rights reserved.
//

import Defaults
import Foundation
import SwiftUI

// MARK: - AIExplainProvider

/// Describes the remote protocol used by the AI explanation popover. The
/// provider keeps endpoint and request-shape choices separate so Anthropic
/// compatible servers are not forced through OpenAI-compatible payloads.
enum AIExplainProvider: String, CaseIterable {
    case openAICompatible = "openai_compatible"
    case anthropicCompatible = "anthropic_compatible"

    // MARK: Internal

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .openAICompatible:
            "ai_explain.provider.openai_compatible"
        case .anthropicCompatible:
            "ai_explain.provider.anthropic_compatible"
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .openAICompatible:
            "ai_explain.provider.openai_compatible"
        case .anthropicCompatible:
            "ai_explain.provider.anthropic_compatible"
        }
    }

    var defaultEndpoint: String {
        switch self {
        case .openAICompatible:
            "https://api.openai.com/v1/chat/completions"
        case .anthropicCompatible:
            "https://api.anthropic.com/v1/messages"
        }
    }

    var defaultModel: String {
        switch self {
        case .openAICompatible:
            "gpt-5-mini"
        case .anthropicCompatible:
            "claude-sonnet-4-6"
        }
    }
}

// MARK: Defaults.Serializable

extension AIExplainProvider: Defaults.Serializable {
    static let bridge = Bridge()

    struct Bridge: Defaults.Bridge {
        typealias Value = AIExplainProvider
        typealias Serializable = String

        func serialize(_ value: AIExplainProvider?) -> String? {
            value?.rawValue
        }

        func deserialize(_ object: String?) -> AIExplainProvider? {
            guard let object else { return nil }
            return AIExplainProvider(rawValue: object)
        }
    }
}

// MARK: - AIExplainOutputLanguage

/// Controls the language used by the initial AI explanation request. Keeping
/// this separate from the editable system prompt gives users a simple switch
/// while still allowing advanced prompt customization.
enum AIExplainOutputLanguage: String, CaseIterable {
    case simplifiedChinese = "zh-Hans"
    case english = "en"

    // MARK: Internal

    var title: LocalizedStringKey {
        switch self {
        case .simplifiedChinese:
            "ai_explain.output_language.simplified_chinese"
        case .english:
            "ai_explain.output_language.english"
        }
    }

    var responseInstruction: String {
        switch self {
        case .simplifiedChinese:
            "请使用简体中文回答。"
        case .english:
            "Respond in English."
        }
    }

    func initialPrompt(for text: String) -> String {
        switch self {
        case .simplifiedChinese:
            """
            请解释以下文本：

            \"\"\"
            \(text)
            \"\"\"
            """
        case .english:
            """
            Explain the following text:

            \"\"\"
            \(text)
            \"\"\"
            """
        }
    }
}

// MARK: Defaults.Serializable

extension AIExplainOutputLanguage: Defaults.Serializable {
    static let bridge = Bridge()

    struct Bridge: Defaults.Bridge {
        typealias Value = AIExplainOutputLanguage
        typealias Serializable = String

        func serialize(_ value: AIExplainOutputLanguage?) -> String? {
            value?.rawValue
        }

        func deserialize(_ object: String?) -> AIExplainOutputLanguage? {
            guard let object else { return nil }
            return AIExplainOutputLanguage(rawValue: object)
        }
    }
}
