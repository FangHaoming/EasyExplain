//
//  AIExplainMessage.swift
//  Easydict
//
//  Created by fanghaoming on 2026/7/2.
//  Copyright © 2026 izual. All rights reserved.
//

import Foundation

// MARK: - AIExplainMessage

/// Represents one visible or request-only message in an explanation session.
/// The popover keeps these messages in memory for follow-up turns, then drops
/// them when the popover closes.
struct AIExplainMessage: Identifiable, Equatable {
    // MARK: Lifecycle

    init(id: UUID = UUID(), role: Role, content: String) {
        self.id = id
        self.role = role
        self.content = content
    }

    // MARK: Internal

    enum Role: String, Codable {
        case system
        case user
        case assistant
    }

    let id: UUID
    let role: Role
    var content: String
}
