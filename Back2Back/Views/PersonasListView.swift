import SwiftUI
import Observation

struct PersonasListView: View {
    @Bindable private var viewModel: PersonasViewModel
    @State private var showingAddPersona = false
    @State private var showingDetailView: Persona?
    @State private var personaToDelete: Persona?
    @State private var showingDeleteAlert = false

    init(viewModel: PersonasViewModel) {
        self._viewModel = Bindable(wrappedValue: viewModel)
    }

    var body: some View {
        List {
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
        }
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
        let dependencies = AppDependencies()
        PersonasListView(viewModel: dependencies.personasViewModel)
    }
}
