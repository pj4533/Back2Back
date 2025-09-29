import Foundation
import Observation
import OSLog

@Observable
@MainActor
final class OpenAIClient {
    static let shared = OpenAIClient()

    let environmentService = EnvironmentService.shared
    let session: URLSession
    var apiKey: String?

    private static var isInitialized = false

    private init() {
        let configuration = URLSessionConfiguration.default
        // Disable timeouts for AI generation - web search can take very long
        configuration.timeoutIntervalForRequest = 0  // No timeout
        configuration.timeoutIntervalForResource = 0  // No timeout
        self.session = URLSession(configuration: configuration)

        // Prevent duplicate initialization logs
        if !Self.isInitialized {
            B2BLog.ai.debug("OpenAIClient initialized (singleton)")
            Self.isInitialized = true
        }
        loadAPIKey()
    }

    private func loadAPIKey() {
        apiKey = environmentService.getOpenAIKey()
        if apiKey != nil {
            B2BLog.ai.info("OpenAI API key loaded successfully")
        } else {
            B2BLog.ai.error("Failed to load OpenAI API key")
        }
    }

    // MARK: - Configuration

    var isConfigured: Bool {
        apiKey != nil && !apiKey!.isEmpty
    }

    func reloadConfiguration() {
        B2BLog.ai.debug("Reloading OpenAI configuration")
        loadAPIKey()
    }
}