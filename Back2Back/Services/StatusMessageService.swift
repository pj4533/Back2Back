//
//  StatusMessageService.swift
//  Back2Back
//
//  Created on 2025-10-05.
//  Dynamic status message generation using Foundation Models framework
//

import Foundation
import FoundationModels
import OSLog

@MainActor
final class StatusMessageService {
    private let userDefaults = UserDefaults.standard
    private let cacheKey = "com.back2back.statusMessagesCache"
    private var cachedMessages: [UUID: CachedStatusMessages] = [:]
    private var isGenerating = false
    private let openAIClient: OpenAIClient

    init(openAIClient: OpenAIClient) {
        self.openAIClient = openAIClient
        B2BLog.ai.info("StatusMessageService initialized")
        loadCache()
    }

    // MARK: - Public API

    /// Get status messages for a persona (returns cached or generates new)
    /// This method uses a fire-and-forget pattern for non-blocking generation
    /// Returns default messages only if no cache exists, otherwise returns cached while regenerating
    func getStatusMessages(for persona: Persona) -> StatusMessages {
        // Check if we have any cached messages
        if let cached = cachedMessages[persona.id] {
            // We have cache - return it
            B2BLog.ai.debug("Using cached status messages for persona: \(persona.name)")

            // If regeneration is needed, trigger background generation while returning old cache
            if cached.shouldRegenerate && !isGenerating {
                B2BLog.ai.info("Cache needs regeneration, starting background generation for persona: \(persona.name)")
                generateMessages(for: persona)
            }

            return cached.messages
        }

        // No cache exists - start generation and return defaults
        B2BLog.ai.info("No cache found for persona: \(persona.name), generating new messages")
        if !isGenerating {
            generateMessages(for: persona)
        }

        return fallbackMessages()
    }

    /// Increment usage count for a persona's cached messages
    func incrementUsageCount(for personaId: UUID) {
        guard var cached = cachedMessages[personaId] else { return }

        cached.usageCount += 1
        cachedMessages[personaId] = cached
        persistCache()

        B2BLog.ai.debug("Incremented usage count to \(cached.usageCount) for persona \(personaId)")

        if cached.shouldRegenerate {
            B2BLog.ai.info("Usage threshold reached (\(cached.usageCount)/3), will regenerate on next access")
        }
    }

    /// Clear cache for a specific persona
    func clearCache(for personaId: UUID) {
        if cachedMessages[personaId] != nil {
            cachedMessages.removeValue(forKey: personaId)
            persistCache()
            B2BLog.ai.info("Cleared status message cache for persona \(personaId)")
        }
    }

    /// Clear all cached messages (for testing/debugging)
    func clearAllCaches() {
        cachedMessages.removeAll()
        persistCache()
        B2BLog.ai.warning("Cleared all status message caches")
    }

    /// Pregenerate status messages for a persona if needed
    /// Called proactively (on app start or persona change) to ensure messages are ready
    func pregenerateMessages(for persona: Persona) {
        // Check if we already have valid cached messages
        if let cached = cachedMessages[persona.id], !cached.shouldRegenerate {
            B2BLog.ai.debug("Pregeneration skipped - valid cache exists for persona: \(persona.name)")
            return
        }

        // Either no cache or regeneration needed - start generation
        B2BLog.ai.info("Pregenerating status messages for persona: \(persona.name)")

        if !isGenerating {
            generateMessages(for: persona)
        } else {
            B2BLog.ai.debug("Generation already in progress, skipping pregeneration")
        }
    }

    // MARK: - Private Methods

    /// Generate messages using Foundation Models framework (fire-and-forget pattern)
    private func generateMessages(for persona: Persona) {
        // Fire-and-forget pattern to avoid blocking UI
        Task.detached { @MainActor [weak self] in
            guard let self else { return }

            guard !self.isGenerating else {
                B2BLog.ai.debug("Status message generation already in progress, skipping")
                return
            }

            self.isGenerating = true
            defer { self.isGenerating = false }

            do {
                B2BLog.ai.info("Generating status messages for persona: \(persona.name)")

                let model = SystemLanguageModel(useCase: .general)
                let session = LanguageModelSession(model: model)

                let prompt = """
                Generate three short (3-5 words), fun status messages for a DJ assistant AI \
                with this personality:

                Name: \(persona.name)
                Description: \(persona.description)
                Style: \(persona.styleGuide)

                The messages should reflect the persona's musical style and be appropriate \
                for displaying while the AI is selecting the next song. Be creative and \
                genre-specific, but keep messages brief and energetic.

                Examples for different styles:
                - Hip-hop: "Digging through crates...", "Finding that boom bap...", "Hunting for beats..."
                - Classical: "Searching the repertoire...", "Selecting a masterpiece...", "Consulting the masters..."
                - Electronic: "Programming the sequence...", "Layering the textures...", "Building the drop..."
                """

                let response = try await session.respond(
                    to: prompt,
                    generating: StatusMessages.self
                )

                // Cache the result
                let cached = CachedStatusMessages(
                    messages: response.content,
                    personaId: persona.id,
                    generatedAt: Date(),
                    usageCount: 0
                )
                self.cachedMessages[persona.id] = cached
                self.persistCache()

                B2BLog.ai.info("Generated status messages: '\(response.content.message1)', '\(response.content.message2)', '\(response.content.message3)'")
            } catch {
                B2BLog.ai.error("Failed to generate status messages: \(error)")
                // Fallback messages will be used automatically
            }
        }
    }

    /// Default fallback messages when generation fails or is unavailable
    private func fallbackMessages() -> StatusMessages {
        StatusMessages(
            message1: "Analyzing the vibe...",
            message2: "Searching the catalog...",
            message3: "Finding the perfect track..."
        )
    }

    private func loadCache() {
        guard let data = userDefaults.data(forKey: cacheKey) else {
            B2BLog.ai.debug("No saved status message caches found")
            return
        }

        do {
            let decodedCaches = try JSONDecoder().decode([CachedStatusMessages].self, from: data)
            cachedMessages = Dictionary(uniqueKeysWithValues: decodedCaches.map { ($0.personaId, $0) })
            B2BLog.ai.info("Loaded \(self.cachedMessages.count) status message caches")
        } catch {
            B2BLog.ai.error("Failed to load status message caches: \(error)")
        }
    }

    private func persistCache() {
        let cachesArray = Array(cachedMessages.values)

        do {
            let encoded = try JSONEncoder().encode(cachesArray)
            userDefaults.set(encoded, forKey: cacheKey)
            B2BLog.ai.debug("Saved \(cachesArray.count) status message caches")
        } catch {
            B2BLog.ai.error("Failed to save status message caches: \(error)")
        }
    }
}
