import Testing
import Foundation
@testable import Back2Back

@MainActor
struct PersonasViewModelTests {

    @Test("PersonasViewModel loads personas on initialization")
    func testLoadPersonas() {
        // Given
        let viewModel = PersonasViewModel()

        // When
        viewModel.loadPersonas()

        // Then
        #expect(viewModel.personas.count > 0)
        #expect(viewModel.selectedPersona != nil)
    }

    @Test("Create persona through ViewModel")
    func testCreatePersona() async {
        // Given
        let viewModel = PersonasViewModel()
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
        let viewModel = PersonasViewModel()
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
        let viewModel = PersonasViewModel()
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
        let viewModel = PersonasViewModel()
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
        let viewModel = PersonasViewModel()

        // Initial state
        #expect(viewModel.isGeneratingStyleGuide == false)
        #expect(viewModel.generationError == nil)
        #expect(viewModel.lastGeneratedSources.isEmpty)
    }

    @Test("Regenerate style guide for existing persona")
    func testRegenerateStyleGuide() async {
        // Given
        let viewModel = PersonasViewModel()
        let persona = Persona(
            name: "Test Persona",
            description: "Test description",
            styleGuide: "Old style guide"
        )

        // This test would need mocking of OpenAIClient to properly test
        // For now, we just verify the method exists and can be called
        await viewModel.regenerateStyleGuide(for: persona)

        // In a real test with mocking, we would verify:
        // - isGeneratingStyleGuide becomes true then false
        // - The persona's styleGuide is updated
        // - lastGeneratedSources is populated
    }
}