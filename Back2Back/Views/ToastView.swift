//
//  ToastView.swift
//  Back2Back
//
//  Created on 2025-10-12.
//  Toast notification UI component with animations similar to AILoadingCell
//

import SwiftUI

struct ToastView: View {
    let toast: Toast
    let onDismiss: () -> Void

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: toast.type.icon)
                .font(.title2)
                .foregroundStyle(
                    LinearGradient(
                        colors: toast.type.gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolEffect(.bounce, options: .repeating)

            // Message
            VStack(alignment: .leading, spacing: 4) {
                Text(toast.message)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)

                // Optional action button
                if let action = toast.action {
                    Button(action: {
                        action.action()
                        onDismiss()
                    }) {
                        Text(action.label)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: toast.type.gradient,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Dismiss button
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            // Use Material background for optimal readability and iOS-native appearance
            RoundedRectangle(cornerRadius: 12)
                .fill(toast.type.backgroundMaterial)
                .shadow(color: toast.type.color.opacity(0.3), radius: 12, x: 0, y: 4)
        )
        .overlay(
            // Colored border for visual hierarchy and type identification
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            toast.type.color.opacity(0.6),
                            toast.type.color.opacity(0.4)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
        .offset(y: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    // Only allow downward dragging
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height > 50 {
                        // Dismiss if dragged down enough
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            dragOffset = 200
                        }
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(200))
                            onDismiss()
                        }
                    } else {
                        // Snap back
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            dragOffset = 0
                        }
                    }
                }
        )
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Spacer()
        ToastView(
            toast: Toast(
                id: UUID(),
                message: "No good match found for: 'Psychedelic Dream' by 'The Mind Benders' after searching 100 results",
                type: .error,
                duration: 4.0,
                action: ToastAction(label: "Retry", action: {})
            ),
            onDismiss: {}
        )
        .padding()
    }
    .background(Color.gray.opacity(0.1))
}
