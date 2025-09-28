import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class PersonaService {
    static let shared = PersonaService()

    private let userDefaults = UserDefaults.standard
    private let personasKey = "com.back2back.personas"
    private let selectedPersonaIdKey = "com.back2back.selectedPersonaId"

    var personas: [Persona] = []
    var selectedPersona: Persona? {
        personas.first { $0.isSelected }
    }

    private init() {
        loadPersonas()
        if personas.isEmpty {
            createDefaultPersonas()
        }
    }

    func loadPersonas() {
        B2BLog.general.info("Loading personas")

        if let data = userDefaults.data(forKey: personasKey),
           let decoded = try? JSONDecoder().decode([Persona].self, from: data) {
            personas = decoded
            B2BLog.general.info("Loaded \(decoded.count) personas")
        } else {
            B2BLog.general.info("No saved personas found")
        }
    }

    private func savePersonas() {
        B2BLog.general.info("Saving \(self.personas.count) personas")

        if let encoded = try? JSONEncoder().encode(personas) {
            userDefaults.set(encoded, forKey: personasKey)
            B2BLog.general.info("✅ Personas saved successfully")
        } else {
            B2BLog.general.error("❌ Failed to save personas")
        }
    }

    private func createDefaultPersonas() {
        B2BLog.general.info("Creating default personas")

        let rareGrooveCollector = Persona(
            name: "Rare Groove Collector",
            description: "Vinyl crate-digging DJ collector specializing in soul and funk music from the 1960s-1980s. Deep knowledge of rare grooves, B-sides, and underground classics.",
            styleGuide: """
            Vinyl crate-digging DJ collector specializing in soul and funk music from the 1960s-1980s. Deep knowledge of rare grooves, B-sides, and underground classics. Selections flow based on groove, tempo, and vibe rather than just genre matching. Prioritizes obscure tracks, forgotten B-sides, limited regional releases, and deep album cuts over well-known hits. Focuses on lesser-known artists, regional labels, and underground movements. Emphasizes discovering hidden gems and sharing musical archaeology finds. Values authentic recordings, original pressings, and the stories behind the music.
            """,
            isSelected: true
        )

        let modernElectronicDJ = Persona(
            name: "Modern Electronic DJ",
            description: "Contemporary electronic music enthusiast focused on house, techno, and progressive sounds from the current decade.",
            styleGuide: """
            Contemporary electronic music DJ specializing in modern house, techno, and progressive sounds. Stays current with the latest releases, emerging artists, and underground labels. Focuses on innovative production techniques, cutting-edge sound design, and forward-thinking arrangements. Prioritizes tracks that push boundaries while maintaining dancefloor energy. Values both established producers and rising talents in the electronic music scene.
            """,
            isSelected: false
        )

        personas = [rareGrooveCollector, modernElectronicDJ]
        savePersonas()
    }

    func getAllPersonas() -> [Persona] {
        return personas
    }

    func createPersona(name: String, description: String, styleGuide: String = "") -> Persona {
        B2BLog.general.info("Creating new persona: \(name)")

        let persona = Persona(
            name: name,
            description: description,
            styleGuide: styleGuide,
            isSelected: personas.isEmpty
        )

        personas.append(persona)
        savePersonas()

        B2BLog.general.info("✅ Created persona: \(name)")
        return persona
    }

    func updatePersona(_ persona: Persona) {
        B2BLog.general.info("Updating persona: \(persona.name)")

        if let index = personas.firstIndex(where: { $0.id == persona.id }) {
            var updatedPersona = persona
            updatedPersona.updatedAt = Date()
            personas[index] = updatedPersona
            savePersonas()
            B2BLog.general.info("✅ Updated persona: \(persona.name)")
        } else {
            B2BLog.general.error("❌ Failed to find persona for update: \(persona.id)")
        }
    }

    func deletePersona(_ persona: Persona) {
        B2BLog.general.info("Deleting persona: \(persona.name)")

        personas.removeAll { $0.id == persona.id }

        // If deleted persona was selected and there are other personas, select the first one
        if persona.isSelected && !personas.isEmpty {
            selectPersona(personas[0])
        }

        savePersonas()
        B2BLog.general.info("✅ Deleted persona: \(persona.name)")
    }

    func selectPersona(_ persona: Persona) {
        B2BLog.general.info("Selecting persona: \(persona.name)")

        // Deselect all personas
        for i in 0..<personas.count {
            personas[i].isSelected = false
        }

        // Select the specified persona
        if let index = personas.firstIndex(where: { $0.id == persona.id }) {
            personas[index].isSelected = true
            savePersonas()
            B2BLog.general.info("✅ Selected persona: \(persona.name)")
        } else {
            B2BLog.general.error("❌ Failed to find persona for selection: \(persona.id)")
        }
    }
}