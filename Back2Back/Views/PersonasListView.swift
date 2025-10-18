import SwiftUI

struct PersonasListView: View {
    @Environment(\.services) private var services
    @State private var showingAddPersona = false
    @State private var showingDetailView: Persona?
    @State private var showingCacheView: Persona?
    @State private var personaToDelete: Persona?
    @State private var showingDeleteAlert = false

    var body: some View {
        guard let services = services else {
            return AnyView(Text("Loading..."))
        }

        let viewModel = services.personasViewModel

        return AnyView(List {
            ForEach(viewModel.personas) { persona in
                PersonaRow(persona: persona,
                          isSelected: persona.isSelected)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Tap to select the persona
                        if !persona.isSelected {
                            viewModel.selectPersona(persona)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            personaToDelete = persona
                            showingDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }

                        Button {
                            showingDetailView = persona
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.orange)

                        Button {
                            showingCacheView = persona
                        } label: {
                            Label("Cache", systemImage: "tray.full.fill")
                        }
                        .tint(.blue)
                    }
            }
        }
        .navigationTitle("Personas")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddPersona = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(item: $showingDetailView) { persona in
            NavigationStack {
                PersonaDetailView(persona: persona, personasViewModel: viewModel)
            }
        }
        .sheet(isPresented: $showingAddPersona) {
            NavigationStack {
                PersonaDetailView(persona: nil, personasViewModel: viewModel)
            }
        }
        .sheet(item: $showingCacheView) { persona in
            NavigationStack {
                PersonaCacheView(persona: persona, cacheService: services.personaSongCacheService)
            }
        }
        .alert("Delete Persona", isPresented: $showingDeleteAlert, presenting: personaToDelete) { persona in
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                withAnimation {
                    viewModel.deletePersona(persona)
                }
            }
        } message: { persona in
            Text("Are you sure you want to delete '\(persona.name)'?")
        }
        .onAppear {
            viewModel.loadPersonas()
        })
    }
}

struct PersonaRow: View {
    let persona: Persona
    let isSelected: Bool

    var body: some View {
        HStack {
            // Checkmark on the left
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .blue : .gray)
                .font(.title2)
                .animation(.easeInOut(duration: 0.2), value: isSelected)

            VStack(alignment: .leading, spacing: 4) {
                Text(persona.name)
                    .font(.headline)
                    .foregroundColor(isSelected ? .primary : .primary)

                Text(persona.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            // Small indicator that it's the active persona
            if isSelected {
                Text("Active")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        PersonasListView()
    }
}