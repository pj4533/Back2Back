import Foundation
import Observation
import MusicKit
import OSLog

@MainActor
@Observable
final class PersonasViewModel {
    private let personaService = PersonaService.shared
    private let openAIClient = OpenAIClient.shared

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
        await generateStyleGuide(for: name, description: description)
    }

    func generateStyleGuide(for name: String, description: String) async {
        B2BLog.ai.info("Generating style guide for: \(name)")
        isGeneratingStyleGuide = true
        generationStatus = "Connecting to OpenAI..."
        generationError = nil
        lastGeneratedSources = []

        do {
            // Update status to show we're searching
            generationStatus = "Searching the web for information about \(name)..."

            // Small delay to ensure UI updates
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second

            generationStatus = "Analyzing persona characteristics..."

            let result = try await openAIClient.generatePersonaStyleGuide(
                name: name,
                description: description
            )

            generationStatus = "Finalizing style guide..."

            // Update the persona with the generated style guide
            if let persona = personas.first(where: { $0.name == name }) {
                var updatedPersona = persona
                updatedPersona.styleGuide = result.styleGuide
                personaService.updatePersona(updatedPersona)
                lastGeneratedSources = result.sources
                generationStatus = "Style guide generated successfully!"
                B2BLog.ai.info("✅ Style guide generated successfully")

                // Clear status after a moment
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                    generationStatus = ""
                }
            }
        } catch {
            B2BLog.ai.error("❌ Failed to generate style guide: \(error)")
            generationError = error.localizedDescription
            generationStatus = "Generation failed"
        }

        isGeneratingStyleGuide = false
    }

    func regenerateStyleGuide(for persona: Persona) async {
        await generateStyleGuide(for: persona.name, description: persona.description)
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
}