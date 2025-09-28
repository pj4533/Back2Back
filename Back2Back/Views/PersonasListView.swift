import SwiftUI

struct PersonasListView: View {
    @State private var viewModel = PersonasViewModel()
    @State private var showingAddPersona = false
    @State private var showingDetailView: Persona?
    @State private var personaToDelete: Persona?
    @State private var showingDeleteAlert = false

    var body: some View {
        List {
            ForEach(viewModel.personas) { persona in
                PersonaRow(persona: persona,
                          isSelected: persona.isSelected)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showingDetailView = persona
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            personaToDelete = persona
                            showingDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }

                        if !persona.isSelected {
                            Button {
                                viewModel.selectPersona(persona)
                            } label: {
                                Label("Select", systemImage: "checkmark")
                            }
                            .tint(.blue)
                        }
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
                PersonaDetailView(persona: persona, viewModel: viewModel)
            }
        }
        .sheet(isPresented: $showingAddPersona) {
            NavigationStack {
                PersonaDetailView(persona: nil, viewModel: viewModel)
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
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(persona.name)
                        .font(.headline)

                    if isSelected {
                        Text("SELECTED")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .cornerRadius(4)
                    }
                }

                Text(persona.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
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