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
    @Environment(\.dismiss) var dismiss

    var isNewPersona: Bool {
        persona == nil
    }

    var body: some View {
        Form {
            Section("Persona Details") {
                TextField("Name", text: $name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

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
                }
            }

            Section("Style Guide") {
                if styleGuide.isEmpty && isNewPersona {
                    VStack(alignment: .center, spacing: 12) {
                        if isGenerating {
                            // Show different icon based on status
                            Group {
                                if generationStatusMessage.contains("✅") {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.system(size: 36))
                                } else if generationStatusMessage.contains("❌") {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                        .font(.system(size: 36))
                                } else if generationStatusMessage.contains("🔎") {
                                    Image(systemName: "magnifyingglass.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.system(size: 36))
                                        .symbolEffect(.pulse, options: .repeating)
                                } else if generationStatusMessage.contains("✍️") {
                                    Image(systemName: "pencil.circle.fill")
                                        .foregroundColor(.orange)
                                        .font(.system(size: 36))
                                        .symbolEffect(.pulse, options: .repeating)
                                } else {
                                    ProgressView()
                                        .scaleEffect(1.2)
                                }
                            }
                            .padding(.bottom, 8)

                            Text(generationStatusMessage.isEmpty ? "Preparing to generate..." : generationStatusMessage)
                                .font(.subheadline)
                                .foregroundColor(generationStatusMessage.contains("❌") ? .red : .primary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .animation(.easeInOut(duration: 0.3), value: generationStatusMessage)
                        } else if !styleGuide.isEmpty {
                            // Show the generated style guide
                            ScrollView {
                                Text(styleGuide)
                                    .font(.system(.body, design: .default))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .background(Color.gray.opacity(0.05))
                                    .cornerRadius(8)
                            }
                            .frame(minHeight: 150, maxHeight: 300)
                        } else {
                            Text("Generate a style guide for this persona")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }

                        // Generate button for new personas
                        if !isGenerating && styleGuide.isEmpty {
                            Button(action: {
                                Task {
                                    isGenerating = true
                                    generationStatusMessage = ""

                                    // Create a task to monitor status updates
                                    Task {
                                        while isGenerating {
                                            generationStatusMessage = viewModel.generationStatus
                                            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                                        }
                                        generationStatusMessage = ""
                                    }

                                    await viewModel.generateStyleGuide(for: name, description: description)
                                    if let updatedPersona = viewModel.personas.first(where: { $0.name == name }) {
                                        styleGuide = updatedPersona.styleGuide
                                    }
                                    isGenerating = false
                                }
                            }) {
                                HStack {
                                    Image(systemName: "sparkles.rectangle.stack.fill")
                                    Text("Generate Style Guide")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(name.isEmpty || description.isEmpty)
                        }
                    }
                    .padding(.vertical, 20)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("AI-Generated Guide")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Spacer()

                            if !viewModel.lastGeneratedSources.isEmpty {
                                Button(action: { showingSources = true }) {
                                    Label("Sources", systemImage: "link.circle")
                                        .font(.caption)
                                }
                            }
                        }

                        // Show status during generation
                        if isGenerating && !generationStatusMessage.isEmpty {
                            HStack(spacing: 8) {
                                // Show different icon based on status
                                if generationStatusMessage.contains("✅") {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.system(size: 14))
                                } else if generationStatusMessage.contains("❌") {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                        .font(.system(size: 14))
                                } else if generationStatusMessage.contains("🔎") {
                                    Image(systemName: "magnifyingglass.circle.fill")
                                        .foregroundColor(.blue)
                                        .font(.system(size: 14))
                                } else if generationStatusMessage.contains("✍️") {
                                    Image(systemName: "pencil.circle.fill")
                                        .foregroundColor(.orange)
                                        .font(.system(size: 14))
                                } else {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                }

                                Text(generationStatusMessage)
                                    .font(.subheadline)
                                    .foregroundColor(generationStatusMessage.contains("❌") ? .red : .primary)
                                    .animation(.easeInOut(duration: 0.3), value: generationStatusMessage)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(6)
                            .animation(.spring(response: 0.3), value: generationStatusMessage)
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
                        .opacity(isGenerating ? 0.5 : 1.0)

                        Button(action: {
                            Task {
                                isGenerating = true
                                generationStatusMessage = ""

                                // Create a task to monitor status updates
                                Task {
                                    while isGenerating {
                                        generationStatusMessage = viewModel.generationStatus
                                        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                                    }
                                    generationStatusMessage = ""
                                }

                                await viewModel.generateStyleGuide(for: name, description: description)
                                if let updatedPersona = viewModel.personas.first(where: { $0.name == name }) {
                                    styleGuide = updatedPersona.styleGuide
                                }
                                isGenerating = false
                            }
                        }) {
                            HStack {
                                if isGenerating {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .frame(width: 20, height: 20)
                                } else {
                                    Image(systemName: "arrow.clockwise.circle.fill")
                                }
                                Text(styleGuide.isEmpty ? "Generate Style Guide" : "Regenerate Style Guide")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isGenerating || name.isEmpty || description.isEmpty)
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
                Button("Save") {
                    savePersona()
                }
                .fontWeight(.bold)
                .disabled(name.isEmpty || description.isEmpty || (isNewPersona && styleGuide.isEmpty))
            }
        }
        .sheet(isPresented: $showingSources) {
            NavigationStack {
                SourcesListView(sources: viewModel.lastGeneratedSources)
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

#Preview {
    NavigationStack {
        PersonaDetailView(persona: nil, viewModel: PersonasViewModel())
    }
}