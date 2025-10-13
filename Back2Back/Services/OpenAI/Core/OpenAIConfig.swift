import Foundation
import OSLog

struct OpenAIConfig {
    let environmentService: EnvironmentService
    private(set) var apiKey: String?

    init(environmentService: EnvironmentService) {
        self.environmentService = environmentService
        self.apiKey = environmentService.getOpenAIKey()

        if apiKey != nil {
            B2BLog.ai.info("OpenAI API key loaded successfully")
        } else {
            B2BLog.ai.error("Failed to load OpenAI API key")
        }
    }

    var isConfigured: Bool {
        apiKey != nil && !apiKey!.isEmpty
    }

    mutating func reload() {
        B2BLog.ai.debug("Reloading OpenAI configuration")
        apiKey = environmentService.getOpenAIKey()
    }
}

struct OpenAIConstants {
    static let baseURL = "https://api.openai.com"
    static let responsesEndpoint = "/v1/responses"
}
