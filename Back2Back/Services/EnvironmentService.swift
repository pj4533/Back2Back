import Foundation
import Observation
import OSLog

@Observable
@MainActor
final class EnvironmentService {
    private let processInfo: ProcessInfo
    private var cachedOpenAIKey: String?

    init(processInfo: ProcessInfo = .processInfo) {
        self.processInfo = processInfo
        B2BLog.general.debug("EnvironmentService initialized")
        loadEnvironmentVariables()
    }

    private func loadEnvironmentVariables() {
        B2BLog.network.debug("Loading API keys from environment variables...")

        // First try environment variables (useful for local development)
        cachedOpenAIKey = processInfo.environment["OPENAI_API_KEY"]

        // If not found in environment, try the generated Secrets file (for CI builds)
        if cachedOpenAIKey == nil {
            cachedOpenAIKey = Secrets.openAIAPIKey
        }

        // Log status (without exposing actual keys)
        B2BLog.network.debug("OpenAI API key status: \(self.cachedOpenAIKey != nil ? "Available" : "Missing")")

        // Validate that we have the required keys
        if self.cachedOpenAIKey == nil {
            B2BLog.network.error("MISSING OPENAI API KEY: Application will fail when attempting to use AI features")
        }
    }

    func getOpenAIKey() -> String? {
        if cachedOpenAIKey == nil || cachedOpenAIKey?.isEmpty == true {
            B2BLog.network.warning("OPENAI_API_KEY not found in environment variables or Secrets file")
        } else {
            B2BLog.network.trace("OpenAI API key retrieved")
        }

        return cachedOpenAIKey
    }

    func getValue(for key: String) -> String? {
        let value = processInfo.environment[key]

        if value == nil || value?.isEmpty == true {
            B2BLog.general.debug("Environment variable '\(key)' not found")
        } else {
            B2BLog.general.trace("Environment variable '\(key)' retrieved")
        }

        return value
    }

    var isConfiguredForOpenAI: Bool {
        cachedOpenAIKey != nil && !cachedOpenAIKey!.isEmpty
    }

    /// Reload environment variables (useful for testing)
    func reload() {
        loadEnvironmentVariables()
    }
}
