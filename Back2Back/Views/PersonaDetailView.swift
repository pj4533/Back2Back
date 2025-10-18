//
//  PersonaDetailView.swift
//  Back2Back
//
//  Refactored as part of Phase 1 architecture improvements (#20)
//

import SwiftUI
import OSLog

struct PersonaDetailView: View {
    let persona: Persona?
    let personasViewModel: PersonasViewModel
    @Bindable var viewModel: PersonaDetailViewModel

    @FocusState private var focusedField: Field?
    @Environment(\.dismiss) var dismiss
    @State private var showingSources = false

    enum Field: Hashable {
        case name
        case description
    }

    init(persona: Persona?, personasViewModel: PersonasViewModel) {
        self.persona = persona
        self.personasViewModel = personasViewModel
        // Use @Bindable for @Observable classes in iOS 17+
        // This properly sets up observation and binding
        self.viewModel = PersonaDetailViewModel(
            persona: persona,
            personasViewModel: personasViewModel
        )
    }

    var isNewPersona: Bool {
        persona == nil
    }

    var body: some View {
        Form {
            personaDetailsSection
            styleGuideSection
            errorSection
        }
        .navigationTitle(isNewPersona ? "New Persona" : "Edit Persona")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            navigationBarToolbar
            keyboardToolbar
        }
        .sheet(isPresented: $showingSources) {
            NavigationStack {
                SourcesListView(sources: viewModel.lastGeneratedSources)
            }
        }
        .overlay {
            if viewModel.showingGenerationModal {
                generationModalOverlay
            }
        }
    }

    // MARK: - View Components

    @ViewBuilder
    private var personaDetailsSection: some View {
        Section("Persona Details") {
            TextField("Name", text: $viewModel.name)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($focusedField, equals: .name)

            VStack(alignment: .leading, spacing: 4) {
                Text("Description")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextEditor(text: $viewModel.description)
                    .frame(minHeight: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .focused($focusedField, equals: .description)
            }
        }
    }

    @ViewBuilder
    private var styleGuideSection: some View {
        Section("Style Guide") {
            VStack(alignment: .leading, spacing: 12) {
                if viewModel.styleGuide.isEmpty {
                    emptyStyleGuideView
                } else {
                    populatedStyleGuideView
                        .onAppear {
                            B2BLog.ui.info("✅ PopulatedStyleGuideView appeared with \(viewModel.styleGuide.count) chars")
                        }
                }

                // Hint when style guide is empty and fields are filled
                if viewModel.styleGuide.isEmpty && viewModel.canGenerate {
                    Text("Use the keyboard toolbar button to generate")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                }
            }
        }
    }

    @ViewBuilder
    private var emptyStyleGuideView: some View {
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
    }

    @ViewBuilder
    private var populatedStyleGuideView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Generated Style Guide")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if !viewModel.lastGeneratedSources.isEmpty {
                    Button(action: { showingSources = true }) {
                        Label(
                            "\(viewModel.lastGeneratedSources.count) Sources",
                            systemImage: "link.circle"
                        )
                        .font(.caption)
                    }
                }
            }

            ScrollView {
                Text(viewModel.styleGuide)
                    .font(.system(.body, design: .default))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
            }
            .frame(minHeight: 150, maxHeight: 300)
        }
    }

    @ViewBuilder
    private var errorSection: some View {
        if let error = viewModel.generationError {
            Section {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
    }

    @ViewBuilder
    private var generationModalOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    if !viewModel.isGenerating {
                        viewModel.showingGenerationModal = false
                    }
                }

            GenerationProgressView(
                statusMessage: viewModel.generationStatusMessage,
                onCancel: nil // Could implement cancellation later
            )
            .frame(width: 320, height: 350)
            .background(Color(UIColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(radius: 20)
            .transition(.scale.combined(with: .opacity))
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.showingGenerationModal)
    }

    // MARK: - Toolbar Items

    @ToolbarContentBuilder
    private var navigationBarToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Cancel") {
                dismiss()
            }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 16) {
                // Show generate button in nav bar when keyboard is not shown
                if focusedField == nil &&
                   viewModel.styleGuide.isEmpty &&
                   viewModel.canGenerate {
                    Button(action: {
                        Task {
                            await viewModel.generateStyleGuide()
                        }
                    }) {
                        Image(systemName: "sparkles")
                    }
                    .disabled(viewModel.isGenerating)
                }

                Button("Save") {
                    Task {
                        if await viewModel.savePersona(originalPersona: persona) {
                            dismiss()
                        }
                    }
                }
                .fontWeight(.bold)
                .disabled(!viewModel.isValid)
            }
        }
    }

    @ToolbarContentBuilder
    private var keyboardToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            if focusedField != nil && viewModel.canGenerate {
                Spacer()

                KeyboardToolbarGenerateButton(
                    hasStyleGuide: viewModel.hasStyleGuide,
                    isGenerating: viewModel.isGenerating
                ) {
                    focusedField = nil
                    Task {
                        await viewModel.generateStyleGuide()
                    }
                }
            }
        }
    }
}

// Preview disabled - requires service container
// #Preview {
//     NavigationStack {
//         PersonaDetailView(persona: nil, personasViewModel: PersonasViewModel())
//     }
// }