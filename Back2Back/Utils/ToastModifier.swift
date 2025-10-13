//
//  ToastModifier.swift
//  Back2Back
//
//  Created on 2025-10-12.
//  View modifier for displaying toast notifications
//

import SwiftUI

/// View modifier that displays toast notifications
struct ToastModifier: ViewModifier {
    let toastService: ToastService

    func body(content: Content) -> some View {
        ZStack {
            content

            // Toast overlay
            if let toast = toastService.currentToast {
                VStack {
                    Spacer()

                    ToastView(toast: toast) {
                        toastService.dismiss()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 80) // Above tab bar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .zIndex(999) // Ensure it's above everything
            }
        }
    }
}

// MARK: - View Extension

extension View {
    /// Attach toast notification support to any view using environment services
    func toastNotifications() -> some View {
        ToastNotificationsView(content: self)
    }
}

/// Helper view to access environment and apply toast modifier
private struct ToastNotificationsView<Content: View>: View {
    @Environment(\.services) private var services
    let content: Content

    var body: some View {
        if let services = services {
            content.modifier(ToastModifier(toastService: services.toastService))
        } else {
            content
        }
    }
}
