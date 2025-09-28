import SwiftUI

struct PersonaDetailView: View {
    let persona: Persona?
    var viewModel: PersonasViewModel

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var styleGuide: String = ""
    @State private var isGenerating = false
    @State private var generationStatusMessage = ""
    @State private var showingSources = false
    @State private var showingGenerationModal = false
    @FocusState private var focusedField: Field?
    @FocusState private var isTextEditorFocused: Bool
    @Environment(\.dismiss) var dismiss

    enum Field: Hashable {
        case name
        case description
    }

    var isNewPersona: Bool {
        persona == nil
    }

    var body: some View {
        Form {
            Section("Persona Details") {
                TextField("Name", text: $name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($focusedField, equals: .name)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Description")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextEditor(text: $description)
                        .frame(minHeight: 80)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .focused($focusedField, equals: .description)
                        .focused($isTextEditorFocused)
                }
            }

            Section("Style Guide") {
                VStack(alignment: .leading, spacing: 12) {
                    // Always show the style guide content area
                    if styleGuide.isEmpty {
                        // Empty state with clear call to action
                        VStack(spacing: 16) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary.opacity(0.5))

                            Text("A style guide is required to save this persona")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)

                            if isNewPersona {
                                Text("Tap the button below to generate one")
                                    .font(.caption)
                                    .foregroundColor(.secondary.opacity(0.8))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 120)
                        .padding()
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(8)
                    } else {
                        // Show the generated style guide
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Generated Style Guide")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Spacer()

                                if !viewModel.lastGeneratedSources.isEmpty {
                                    Button(action: { showingSources = true }) {
                                        Label("\(viewModel.lastGeneratedSources.count) Sources", systemImage: "link.circle")
                                            .font(.caption)
                                    }
                                }
                            }

                            ScrollView {
                                Text(styleGuide)
                                    .font(.system(.body, design: .default))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .background(Color.gray.opacity(0.05))
                                    .cornerRadius(8)
                            }
                            .frame(minHeight: 150, maxHeight: 300)
                        }
                    }

                    // Show a hint when style guide is empty
                    if styleGuide.isEmpty && !name.isEmpty && !description.isEmpty {
                        Text("Use the keyboard toolbar button to generate")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8)
                    }
                }
            }

            if let error = viewModel.generationError {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle(isNewPersona ? "New Persona" : "Edit Persona")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    // Show generate button in nav bar when keyboard is not shown
                    if !isTextEditorFocused && styleGuide.isEmpty && !name.isEmpty && !description.isEmpty {
                        Button(action: {
                            showingGenerationModal = true

                            Task {
                                isGenerating = true
                                generationStatusMessage = ""

                                // Monitor status updates
                                Task {
                                    while isGenerating {
                                        generationStatusMessage = viewModel.generationStatus
                                        try? await Task.sleep(nanoseconds: 100_000_000)
                                    }
                                }

                                // Generate the style guide
                                if let generatedGuide = await viewModel.generateStyleGuide(for: name, description: description) {
                                    styleGuide = generatedGuide
                                }

                                isGenerating = false
                                showingGenerationModal = false
                            }
                        }) {
                            Image(systemName: "sparkles")
                        }
                        .disabled(isGenerating)
                    }

                    Button("Save") {
                        savePersona()
                    }
                    .fontWeight(.bold)
                    .disabled(name.isEmpty || description.isEmpty || styleGuide.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showingSources) {
            NavigationStack {
                SourcesListView(sources: viewModel.lastGeneratedSources)
            }
        }
        .sheet(isPresented: $showingGenerationModal) {
            GenerationProgressView(
                statusMessage: generationStatusMessage,
                onCancel: {
                    // For now, we can't cancel generation
                    // This could be implemented later
                }
            )
            .interactiveDismissDisabled(isGenerating)
        }
        .toolbar {
            // Add keyboard toolbar when description field is focused
            ToolbarItemGroup(placement: .keyboard) {
                if isTextEditorFocused && !name.isEmpty && !description.isEmpty {
                    Spacer()

                    Button(action: {
                        focusedField = nil
                        isTextEditorFocused = false
                        showingGenerationModal = true

                        Task {
                            isGenerating = true
                            generationStatusMessage = ""

                            // Monitor status updates
                            Task {
                                while isGenerating {
                                    generationStatusMessage = viewModel.generationStatus
                                    try? await Task.sleep(nanoseconds: 100_000_000)
                                }
                            }

                            // Generate the style guide
                            if let generatedGuide = await viewModel.generateStyleGuide(for: name, description: description) {
                                styleGuide = generatedGuide
                            }

                            isGenerating = false
                            showingGenerationModal = false
                        }
                    }) {
                        HStack {
                            Image(systemName: styleGuide.isEmpty ? "sparkles.rectangle.stack.fill" : "arrow.clockwise")
                            Text(styleGuide.isEmpty ? "Generate" : "Regenerate")
                        }
                    }
                    .tint(.blue)
                    .buttonStyle(.borderedProminent)
                    .disabled(isGenerating)
                }
            }
        }
        .onAppear {
            if let persona = persona {
                name = persona.name
                description = persona.description
                styleGuide = persona.styleGuide
            }
        }
    }

    private func savePersona() {
        if isNewPersona {
            // For new personas, the style guide should already be generated
            // Create the persona with the pre-generated style guide
            Task {
                await viewModel.createPersonaWithStyleGuide(name: name, description: description, styleGuide: styleGuide)
                dismiss()
            }
        } else if var existingPersona = persona {
            existingPersona.name = name
            existingPersona.description = description
            existingPersona.styleGuide = styleGuide
            viewModel.updatePersona(existingPersona)
            dismiss()
        }
    }
}

struct SourcesListView: View {
    let sources: [String]
    @Environment(\.dismiss) var dismiss

    var body: some View {
        List(sources, id: \.self) { source in
            Link(destination: URL(string: source) ?? URL(string: "https://openai.com")!) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(extractDomain(from: source))
                            .font(.headline)
                        Text(source)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(.blue)
                }
            }
        }
        .navigationTitle("Web Sources")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }

    private func extractDomain(from urlString: String) -> String {
        guard let url = URL(string: urlString),
              let host = url.host else {
            return urlString
        }
        return host.replacingOccurrences(of: "www.", with: "")
    }
}

struct GenerationProgressView: View {
    let statusMessage: String
    let onCancel: (() -> Void)?

    var body: some View {
        VStack(spacing: 24) {
            Text("Generating Style Guide")
                .font(.title2)
                .fontWeight(.semibold)

            // Dynamic icon based on status
            Group {
                if statusMessage.lowercased().contains("complete") {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 60))
                        .symbolEffect(.bounce)
                } else if statusMessage.lowercased().contains("error") {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 60))
                } else if statusMessage.lowercased().contains("analyzing") ||
                         statusMessage.lowercased().contains("processing") {
                    Image(systemName: "brain")
                        .foregroundColor(.purple)
                        .font(.system(size: 60))
                        .symbolEffect(.pulse, options: .repeating)
                } else if statusMessage.lowercased().contains("search") {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.blue)
                        .font(.system(size: 60))
                        .symbolEffect(.pulse, options: .repeating)
                } else if statusMessage.lowercased().contains("writing") ||
                         statusMessage.lowercased().contains("expanding") ||
                         statusMessage.lowercased().contains("generating") {
                    Image(systemName: "pencil")
                        .foregroundColor(.orange)
                        .font(.system(size: 60))
                        .symbolEffect(.pulse, options: .repeating)
                } else {
                    ProgressView()
                        .scaleEffect(2)
                        .frame(height: 60)
                }
            }
            .padding()

            Text(statusMessage.isEmpty ? "Initializing..." : statusMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 250)
                .animation(.easeInOut(duration: 0.3), value: statusMessage)

            Spacer()
        }
        .padding()
        .padding(.top, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
    }
}

#Preview {
    NavigationStack {
        PersonaDetailView(persona: nil, viewModel: PersonasViewModel())
    }
}