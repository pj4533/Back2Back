//
//  GenerationProgressView.swift
//  Back2Back
//
//  Created on 2025-09-30.
//  Extracted from PersonaDetailView as part of Phase 1 refactoring (#20)
//

import SwiftUI

struct GenerationProgressView: View {
    let statusMessage: String
    let onCancel: (() -> Void)?

    var body: some View {
        VStack(spacing: 20) {
            Text("Generating Style Guide")
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.top)

            statusIcon
                .frame(height: 60)

            Text(statusMessage.isEmpty ? "Initializing..." : statusMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 250)
                .animation(.easeInOut(duration: 0.3), value: statusMessage)
                .padding(.bottom)
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var statusIcon: some View {
        Group {
            if statusMessage.lowercased().contains("complete") {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 50))
                    .symbolEffect(.bounce)
            } else if statusMessage.lowercased().contains("error") {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 50))
            } else if statusMessage.lowercased().contains("analyzing") ||
                     statusMessage.lowercased().contains("processing") {
                Image(systemName: "brain")
                    .foregroundColor(.purple)
                    .font(.system(size: 50))
                    .symbolEffect(.pulse, options: .repeating)
            } else if statusMessage.lowercased().contains("search") {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.blue)
                    .font(.system(size: 50))
                    .symbolEffect(.pulse, options: .repeating)
            } else if statusMessage.lowercased().contains("writing") ||
                     statusMessage.lowercased().contains("expanding") ||
                     statusMessage.lowercased().contains("generating") {
                Image(systemName: "pencil")
                    .foregroundColor(.orange)
                    .font(.system(size: 50))
                    .symbolEffect(.pulse, options: .repeating)
            } else {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(height: 50)
            }
        }
    }
}
