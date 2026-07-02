//
//  AIExplainConfiguration.swift
//  Easydict
//
//  Created by fanghaoming on 2026/7/2.
//  Copyright © 2026 izual. All rights reserved.
//

import Defaults
import Foundation

// MARK: - AIExplainConfiguration

/// Immutable snapshot of the settings used for one AI explanation request.
/// Capturing values before the request starts keeps provider, endpoint, and
/// prompt choices stable while the user edits preferences elsewhere.
struct AIExplainConfiguration {
    static var current: AIExplainConfiguration {
        let provider = Defaults[.aiExplainProvider]
        let storedEndpoint = Defaults[.aiExplainAPIURL].trim()
        let storedModel = Defaults[.aiExplainModel].trim()

        return AIExplainConfiguration(
            provider: provider,
            endpoint: storedEndpoint.isEmpty ? provider.defaultEndpoint : storedEndpoint,
            apiKey: Defaults[.aiExplainAPIKey].trim(),
            model: storedModel.isEmpty ? provider.defaultModel : storedModel,
            outputLanguage: Defaults[.aiExplainOutputLanguage],
            systemPrompt: Defaults[.aiExplainSystemPrompt].trim()
        )
    }

    let provider: AIExplainProvider
    let endpoint: String
    let apiKey: String
    let model: String
    let outputLanguage: AIExplainOutputLanguage
    let systemPrompt: String
}
