//
//  ConfigurationView.swift
//  Back2Back
//
//  Created for GitHub issue #14
//

import SwiftUI
import OSLog

struct ConfigurationView: View {
    @AIModelConfigStorage private var config
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Song Selection Model Configuration")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Picker("Model", selection: $config.songSelectionModel) {
                        Text("GPT-5").tag("gpt-5")
                        Text("GPT-5 Mini").tag("gpt-5-mini")
                        Text("GPT-5 Nano").tag("gpt-5-nano")
                    }
                    .pickerStyle(.menu)
                    
                    Picker("Reasoning Level", selection: $config.songSelectionReasoningLevel) {
                        ForEach(ReasoningEffort.allCases, id: \.self) { level in
                            Text(level.rawValue.capitalized).tag(level)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Text("Style guide creation always uses maximum settings (GPT-5, high reasoning)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                .padding(.vertical, 8)
            } header: {
                Text("AI Settings")
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("These settings control the AI model behavior when selecting songs during your DJ session.")
                    Text("• Higher reasoning levels provide better song selections but take longer")
                    Text("• Smaller models (Mini, Nano) are faster and more cost-effective but may be less creative")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Configuration")
        .navigationBarTitleDisplayMode(.large)
        .onChange(of: config) { oldValue, newValue in
            B2BLog.general.info("AI config changed - Model: \(newValue.songSelectionModel), Reasoning: \(newValue.songSelectionReasoningLevel.rawValue)")
        }
    }
}

#Preview {
    NavigationStack {
        ConfigurationView()
    }
}
