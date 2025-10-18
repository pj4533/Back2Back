import Foundation
import Observation
import MusicKit
import OSLog

@MainActor
@Observable
final class PersonasViewModel {
    private let personaService: PersonaService
    // Use protocol type to enable dependency injection and proper testing
    private let aiService: any AIRecommendationServiceProtocol

    init(personaService: PersonaService, aiService: any AIRecommendationServiceProtocol) {
        self.personaService = personaService
        self.aiService = aiService
    }

    var personas: [Persona] {
        personaService.personas
    }

    var selectedPersona: Persona? {
        personaService.selectedPersona
    }

    var isGeneratingStyleGuide = false
    var generationStatus: String = ""
    var generationError: String?
    var lastGeneratedSources: [String] = []

    func loadPersonas() {
        B2BLog.general.info("Loading personas in ViewModel")
        personaService.loadPersonas()
    }

    func createPersona(name: String, description: String) async {
        B2BLog.general.info("Creating new persona: \(name)")

        // Create the persona with empty style guide initially
        _ = personaService.createPersona(name: name, description: description)

        // Generate the style guide
        _ = await generateStyleGuide(for: name, description: description)
    }

    func generateStyleGuide(for name: String, description: String) async -> String? {
        B2BLog.ai.info("Generating style guide for: \(name)")
        isGeneratingStyleGuide = true
        generationStatus = "Connecting to OpenAI..."
        generationError = nil
        lastGeneratedSources = []

        do {
            // Use streaming API with real-time status updates
            let result = try await aiService.generatePersonaStyleGuide(
                name: name,
                description: description
            ) { [weak self] status in
                await MainActor.run {
                    self?.generationStatus = status
                    B2BLog.ai.debug("Generation status: \(status)")
                }
            }

            // Store the sources
            lastGeneratedSources = result.sources

            // Update the persona if it exists (for regeneration)
            if let persona = personas.first(where: { $0.name == name }) {
                var updatedPersona = persona
                updatedPersona.styleGuide = result.styleGuide
                personaService.updatePersona(updatedPersona)
            }

            // Update final status
            let sourceCount = result.sources.count
            if sourceCount > 0 {
                generationStatus = "✅ Style guide generated using \(sourceCount) source\(sourceCount == 1 ? "" : "s")"
            } else {
                generationStatus = "✅ Style guide generated successfully!"
            }
            B2BLog.ai.info("✅ Style guide generated successfully with \(sourceCount) sources")

            // Clear status after a moment
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                generationStatus = ""
            }

            isGeneratingStyleGuide = false
            B2BLog.ai.info("📤 Returning style guide with length: \(result.styleGuide.count)")
            return result.styleGuide
        } catch {
            B2BLog.ai.error("❌ Failed to generate style guide: \(error)")
            generationError = error.localizedDescription
            generationStatus = "❌ Generation failed: \(error.localizedDescription)"

            // Clear error status after a moment
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                generationStatus = ""
            }

            isGeneratingStyleGuide = false
            return nil
        }
    }

    func regenerateStyleGuide(for persona: Persona) async {
        _ = await generateStyleGuide(for: persona.name, description: persona.description)
    }

    func updatePersona(_ persona: Persona) {
        B2BLog.general.info("Updating persona: \(persona.name)")
        personaService.updatePersona(persona)
    }

    func deletePersona(_ persona: Persona) {
        B2BLog.general.info("Deleting persona: \(persona.name)")
        personaService.deletePersona(persona)
    }

    func selectPersona(_ persona: Persona) {
        B2BLog.general.info("Selecting persona: \(persona.name)")
        personaService.selectPersona(persona)
    }

    func createPersonaWithStyleGuide(name: String, description: String, styleGuide: String) async {
        B2BLog.general.info("Creating persona with pre-generated style guide: \(name)")
        _ = personaService.createPersona(name: name, description: description, styleGuide: styleGuide)
        B2BLog.general.info("✅ Created persona: \(name)")
    }
}