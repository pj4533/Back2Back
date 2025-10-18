import Testing
import Foundation
@testable import Back2Back

@MainActor
struct PersonasViewModelTests {

    func createTestViewModel() -> PersonasViewModel {
        let mockAIService = MockAIRecommendationService()
        let statusMessageService = StatusMessageService(openAIClient: OpenAIClient(
            environmentService: EnvironmentService(),
            personaSongCacheService: PersonaSongCacheService()
        ))
        let personaService = PersonaService(statusMessageService: statusMessageService)
        return PersonasViewModel(personaService: personaService, aiService: mockAIService)
    }

    @Test("PersonasViewModel loads personas on initialization")
    func testLoadPersonas() {
        // Given
        let viewModel = createTestViewModel()

        // When
        viewModel.loadPersonas()

        // Then
        #expect(viewModel.personas.count > 0)
        #expect(viewModel.selectedPersona != nil)
    }

    @Test("Create persona through ViewModel")
    func testCreatePersona() async {
        // Given
        let viewModel = createTestViewModel()
        let initialCount = viewModel.personas.count

        // When
        await viewModel.createPersona(
            name: "Test DJ",
            description: "A test DJ persona"
        )

        // Then
        #expect(viewModel.personas.count == initialCount + 1)
        #expect(viewModel.personas.contains { $0.name == "Test DJ" })
    }

    @Test("Update persona through ViewModel")
    func testUpdatePersona() async {
        // Given
        let viewModel = createTestViewModel()
        await viewModel.createPersona(
            name: "Original DJ",
            description: "Original description"
        )

        guard var persona = viewModel.personas.first(where: { $0.name == "Original DJ" }) else {
            #expect(Bool(false), "Failed to create test persona")
            return
        }

        // When
        persona.name = "Updated DJ"
        persona.description = "Updated description"
        viewModel.updatePersona(persona)

        // Then
        let updatedPersona = viewModel.personas.first { $0.id == persona.id }
        #expect(updatedPersona?.name == "Updated DJ")
        #expect(updatedPersona?.description == "Updated description")
    }

    @Test("Delete persona through ViewModel")
    func testDeletePersona() async {
        // Given
        let viewModel = createTestViewModel()
        await viewModel.createPersona(
            name: "To Delete",
            description: "Will be deleted"
        )

        guard let persona = viewModel.personas.first(where: { $0.name == "To Delete" }) else {
            #expect(Bool(false), "Failed to create test persona")
            return
        }

        let countBeforeDelete = viewModel.personas.count

        // When
        viewModel.deletePersona(persona)

        // Then
        #expect(viewModel.personas.count == countBeforeDelete - 1)
        #expect(!viewModel.personas.contains { $0.id == persona.id })
    }

    @Test("Select persona through ViewModel")
    func testSelectPersona() async {
        // Given
        let viewModel = createTestViewModel()
        await viewModel.createPersona(
            name: "Persona A",
            description: "First persona"
        )
        await viewModel.createPersona(
            name: "Persona B",
            description: "Second persona"
        )

        guard let personaB = viewModel.personas.first(where: { $0.name == "Persona B" }) else {
            #expect(Bool(false), "Failed to create test persona")
            return
        }

        // When
        viewModel.selectPersona(personaB)

        // Then
        #expect(viewModel.selectedPersona?.id == personaB.id)
        #expect(viewModel.selectedPersona?.name == "Persona B")
    }

    @Test("Generation state flags")
    func testGenerationStateFlags() {
        // Given
        let viewModel = createTestViewModel()

        // Initial state
        #expect(viewModel.isGeneratingStyleGuide == false)
        #expect(viewModel.generationError == nil)
        #expect(viewModel.lastGeneratedSources.isEmpty)
    }

    @Test("Regenerate style guide for existing persona")
    func testRegenerateStyleGuide() async {
        // Given
        let viewModel = createTestViewModel()

        // Create persona first
        await viewModel.createPersona(
            name: "Test Persona",
            description: "Test description"
        )

        guard let persona = viewModel.personas.first(where: { $0.name == "Test Persona" }) else {
            #expect(Bool(false), "Failed to create test persona")
            return
        }

        // When
        await viewModel.regenerateStyleGuide(for: persona)

        // Then - Mock provides realistic style guide
        #expect(viewModel.lastGeneratedSources.count > 0, "Should have generated sources")

        // Verify the persona's styleGuide was updated
        let updatedPersona = viewModel.personas.first { $0.id == persona.id }
        #expect(updatedPersona?.styleGuide != nil, "Style guide should be generated")
        #expect(updatedPersona?.styleGuide.contains("DJ Style Guide") == true, "Style guide should contain header")
    }
}