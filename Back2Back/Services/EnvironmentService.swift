import Foundation
import Observation
import OSLog

@Observable
@MainActor
final class EnvironmentService {
    // Use lazy initialization to prevent duplicate init logs
    static let shared = EnvironmentService()

    private let processInfo = ProcessInfo.processInfo
    private var isInitialized = false

    private init() {
        // Prevent duplicate initialization logs
        guard !isInitialized else { return }
        isInitialized = true
        B2BLog.general.debug("EnvironmentService initialized")
    }

    func getOpenAIKey() -> String? {
        let key = processInfo.environment["OPENAI_API_KEY"]

        if key == nil || key?.isEmpty == true {
            B2BLog.network.warning("OPENAI_API_KEY not found in environment variables")
        } else {
            B2BLog.network.trace("OpenAI API key retrieved from environment")
        }

        return key
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
        getOpenAIKey() != nil && !getOpenAIKey()!.isEmpty
    }
}