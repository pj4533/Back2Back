//
//  Toast.swift
//  Back2Back
//
//  Created on 2025-10-12.
//  Toast notification models for user feedback
//

import Foundation
import SwiftUI

/// Represents a toast notification
struct Toast: Identifiable, Equatable {
    let id: UUID
    let message: String
    let type: ToastType
    let duration: TimeInterval
    let action: ToastAction?

    static func == (lhs: Toast, rhs: Toast) -> Bool {
        lhs.id == rhs.id
    }
}

/// Toast type determines styling and icon
enum ToastType {
    case error
    case success
    case info
    case warning

    var color: Color {
        switch self {
        case .error: return .red
        case .success: return .green
        case .info: return .blue
        case .warning: return .orange
        }
    }

    var icon: String {
        switch self {
        case .error: return "exclamationmark.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        }
    }

    var gradient: [Color] {
        switch self {
        case .error:
            return [.red, .pink]
        case .success:
            return [.green, .mint]
        case .info:
            return [.blue, .cyan]
        case .warning:
            return [.orange, .yellow]
        }
    }

    /// Material background provides optimal readability with frosted glass blur effect
    /// - Error/Warning: Use thicker materials for critical information that must be immediately readable
    /// - Success/Info: Use regular material for less critical feedback
    var backgroundMaterial: Material {
        switch self {
        case .error, .warning:
            // Critical messages need maximum readability
            return .ultraThick
        case .success:
            // Success messages are less critical, regular material provides good balance
            return .thick
        case .info:
            // Info messages are least critical, can use lighter material
            return .regular
        }
    }
}

/// Optional action button configuration
struct ToastAction {
    let label: String
    let action: () -> Void
}
