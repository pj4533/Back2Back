import Foundation

struct Persona: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var description: String
    var styleGuide: String
    var isSelected: Bool
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        styleGuide: String = "",
        isSelected: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.styleGuide = styleGuide
        self.isSelected = isSelected
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct PersonaGenerationResult {
    let name: String
    let styleGuide: String
    let sources: [String]
}