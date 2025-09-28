import Foundation
import SwiftUI
import Observation
import OSLog

@MainActor
@Observable
final class PersonaDetailViewModel {
    // Dependencies
    private let personasViewModel: PersonasViewModel

    // State for the form
    var name: String = "" {
        didSet {
            B2BLog.ui.trace("📝 Name changed: \(self.name)")
        }
    }
    var description: String = "" {
        didSet {
            B2BLog.ui.trace("📝 Description changed: \(self.description)")
        }
    }
    var styleGuide: String = "" {
        didSet {
            B2BLog.ui.info("✨ Style guide updated: \(self.styleGuide.isEmpty ? "[empty]" : "[\(self.styleGuide.count) characters]")")
        }
    }

    // Generation state
    var isGenerating = false
    var showingGenerationModal = false
    var generationStatusMessage = ""

    // Sources from last generation
    var lastGeneratedSources: [String] {
        personasViewModel.lastGeneratedSources
    }

    // Error handling
    var generationError: String? {
        personasViewModel.generationError
    }

    // Computed properties
    var isValid: Bool {
        !name.isEmpty && !description.isEmpty && !styleGuide.isEmpty
    }

    var canGenerate: Bool {
        !name.isEmpty && !description.isEmpty && !isGenerating
    }

    var hasStyleGuide: Bool {
        !styleGuide.isEmpty
    }

    init(persona: Persona?, personasViewModel: PersonasViewModel) {
        self.personasViewModel = personasViewModel

        // Initialize with existing persona data if available
        if let persona = persona {
            self.name = persona.name
            self.description = persona.description
            self.styleGuide = persona.styleGuide
        }
    }

    func generateStyleGuide() async {
        guard canGenerate else { return }

        B2BLog.ui.info("Starting style guide generation for \(self.name)")
        isGenerating = true
        showingGenerationModal = true
        generationStatusMessage = "Initializing..."

        // Monitor status updates in a separate task
        let statusTask = Task {
            while isGenerating {
                generationStatusMessage = personasViewModel.generationStatus
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
        }

        // Generate the style guide
        let generatedGuide = await personasViewModel.generateStyleGuide(
            for: name,
            description: description
        )

        B2BLog.ui.info("🔍 Generated guide returned: \(generatedGuide != nil ? "Not nil, length: \(generatedGuide!.count)" : "nil")")

        if let generatedGuide = generatedGuide {
            // Update our local state with the generated guide
            B2BLog.ui.info("🔄 About to set styleGuide, current isEmpty: \(self.styleGuide.isEmpty), new guide length: \(generatedGuide.count)")
            styleGuide = generatedGuide
            B2BLog.ui.info("✅ Style guide generated and applied to form, new isEmpty: \(self.styleGuide.isEmpty), actual length: \(self.styleGuide.count)")
        } else {
            B2BLog.ui.error("Failed to generate style guide")
        }

        // Clean up
        isGenerating = false
        statusTask.cancel()

        // Keep modal visible briefly to show completion status
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            showingGenerationModal = false
            generationStatusMessage = ""
        }
    }

    func savePersona(originalPersona: Persona?) async -> Bool {
        guard isValid else { return false }

        if originalPersona == nil {
            // Create new persona
            await personasViewModel.createPersonaWithStyleGuide(
                name: name,
                description: description,
                styleGuide: styleGuide
            )
            B2BLog.ui.info("Created new persona: \(self.name)")
        } else if var existingPersona = originalPersona {
            // Update existing persona
            existingPersona.name = name
            existingPersona.description = description
            existingPersona.styleGuide = styleGuide
            personasViewModel.updatePersona(existingPersona)
            B2BLog.ui.info("Updated persona: \(self.name)")
        }

        return true
    }
}