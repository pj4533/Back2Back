import SwiftUI

struct OpenAITestView: View {
    @State private var isLoading = false
    @State private var response = ""
    @State private var errorMessage: String?

    private let openAIClient = OpenAIClient.shared

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Status Section
                VStack(alignment: .leading, spacing: 10) {
                    Label {
                        Text(openAIClient.isConfigured ? "API Key Configured" : "API Key Missing")
                    } icon: {
                        Image(systemName: openAIClient.isConfigured ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(openAIClient.isConfigured ? .green : .red)
                    }
                    .font(.headline)

                    if !openAIClient.isConfigured {
                        Text("Set OPENAI_API_KEY in your Xcode scheme's environment variables")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(10)

                // Test Button
                Button(action: testOpenAIConnection) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "bolt.fill")
                        }
                        Text("Test OpenAI Connection")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(openAIClient.isConfigured ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(!openAIClient.isConfigured || isLoading)

                // Response Section
                if !response.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Response:")
                            .font(.headline)
                        Text(response)
                            .font(.body)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                    }
                }

                // Error Section
                if let error = errorMessage {
                    VStack(alignment: .leading) {
                        Label("Error", systemImage: "exclamationmark.triangle.fill")
                            .font(.headline)
                            .foregroundColor(.red)
                        Text(error)
                            .font(.body)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(10)
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("OpenAI Test")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private func testOpenAIConnection() {
        Task {
            await performTest()
        }
    }

    @MainActor
    private func performTest() async {
        isLoading = true
        response = ""
        errorMessage = nil

        B2BLog.ai.info("Starting OpenAI connection test")

        do {
            let testPrompt = "Say 'Hello from Back2Back!' and confirm the connection is working."
            B2BLog.ai.debug("Sending test prompt: \(testPrompt)")

            let result = try await openAIClient.simpleCompletion(prompt: testPrompt)

            B2BLog.ai.info("✅ OpenAI test successful")
            response = result
        } catch {
            B2BLog.ai.error(error, context: "OpenAI connection test failed")
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}