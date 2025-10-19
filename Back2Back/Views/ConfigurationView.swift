//
//  ConfigurationView.swift
//  Back2Back
//
//  Created for GitHub issue #14
//

import SwiftUI
import OSLog
import FoundationModels

struct ConfigurationView: View {
    @Environment(\.services) private var services
    @AIModelConfigStorage private var config
    @State private var showingClearCacheAlert = false

    // Check if Apple Intelligence LLM is available
    private var isLLMAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    var body: some View {
        guard let services = services else {
            return AnyView(Text("Loading..."))
        }

        let errorService = services.songErrorLoggerService

        return AnyView(Form {
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

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Music Matching Strategy")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Picker("Strategy", selection: $config.musicMatcher) {
                        ForEach(MusicMatcherType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    // Show description of selected matcher
                    Text(config.musicMatcher.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)

                    // Show warning if LLM selected but not available
                    if config.musicMatcher == .llmBased && !isLLMAvailable {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("LLM matching requires iOS 26+ with Apple Intelligence enabled. Using string-based matching as fallback.")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        .padding(.top, 8)
                    } else if config.musicMatcher == .llmBased && isLLMAvailable {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Apple Intelligence is available and ready to use for semantic music matching.")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("Music Matching")
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Controls how AI song recommendations are matched against Apple Music search results.")

                    Text("• String-Based: Fast, reliable, works on all devices")
                    Text("• LLM-Based: Semantic understanding, handles variations better (requires Apple Intelligence)")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Song Repetition Prevention")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    HStack {
                        Text("Cache Size")
                        Spacer()
                        TextField("50", value: $config.songCacheSize, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                            .textFieldStyle(.roundedBorder)
                        Text("songs")
                            .foregroundStyle(.secondary)
                    }

                    Text("Personas won't repeat their most recent \(config.songCacheSize) songs")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                .padding(.vertical, 8)
            } header: {
                Text("Song Cache")
            } footer: {
                Text("Controls how many recent songs each persona remembers. Higher values provide more variety but may limit song pool in long sessions. Recommended: 50-100 songs.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                NavigationLink {
                    SongErrorsView()
                } label: {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                        Text("Song Errors")
                        Spacer()
                        if errorService.errors.count > 0 {
                            Text("\(errorService.errors.count)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.red)
                                .clipShape(Capsule())
                        }
                    }
                }

                Button(role: .destructive) {
                    showingClearCacheAlert = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Clear Persona Song Cache")
                    }
                }
            } header: {
                Text("Debug")
            } footer: {
                Text("View failed song selections and clear the song repetition cache. Song selection details are automatically tracked for all AI picks.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Configuration")
        .navigationBarTitleDisplayMode(.large)
        .onChange(of: config) { oldValue, newValue in
            B2BLog.general.info("AI config changed - Model: \(newValue.songSelectionModel), Reasoning: \(newValue.songSelectionReasoningLevel.rawValue), Matcher: \(newValue.musicMatcher.displayName), Cache Size: \(newValue.songCacheSize)")

            // Sync cache size to UserDefaults for PersonaSongCacheService
            UserDefaults.standard.set(newValue.songCacheSize, forKey: "com.back2back.personaSongCacheSize")
        }
        .alert("Clear Song Cache?", isPresented: $showingClearCacheAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                services.personaSongCacheService.clearAllCaches()
                B2BLog.general.info("User cleared persona song cache from config view")
            }
        } message: {
            Text("This will clear the song repetition prevention cache for all personas. AI will be able to select recently played songs immediately.")
        })
    }
}

#Preview {
    NavigationStack {
        ConfigurationView()
    }
}
