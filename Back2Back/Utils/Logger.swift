//
//  Logger.swift
//  Back2Back
//
//  Centralized logging system for the entire application.
//  All logging should go through this system for consistent formatting and filtering.
//

import Foundation
import OSLog

/// Centralized logging system for Back2Back
/// Use B2BLog.subsystem to get the appropriate logger for your component
public struct B2BLog {

    /// Bundle identifier for consistent subsystem naming
    private static let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.back2back"

    /// MusicKit operations logger
    public struct MusicKit {
        private static let logger = Logger(subsystem: "\(bundleIdentifier).MusicKit", category: "General")

        public static func trace(_ message: String) { logger.trace("\(message)") }
        public static func debug(_ message: String) { logger.debug("\(message)") }
        public static func info(_ message: String) { logger.info("\(message)") }
        public static func notice(_ message: String) { logger.notice("\(message)") }
        public static func warning(_ message: String) { logger.warning("⚠️ \(message)") }
        public static func error(_ message: String) { logger.error("❌ \(message)") }
        public static func error(_ error: Error, context: String? = nil) {
            if let context = context {
                logger.error("❌ \(context): \(error.localizedDescription)")
            } else {
                logger.error("❌ \(error.localizedDescription)")
            }
        }
        public static func success(_ message: String) { logger.info("✅ \(message)") }
    }

    /// Authentication operations logger
    public struct Auth {
        private static let logger = Logger(subsystem: "\(bundleIdentifier).Authentication", category: "Authorization")

        public static func trace(_ message: String) { logger.trace("\(message)") }
        public static func debug(_ message: String) { logger.debug("\(message)") }
        public static func info(_ message: String) { logger.info("\(message)") }
        public static func notice(_ message: String) { logger.notice("\(message)") }
        public static func warning(_ message: String) { logger.warning("⚠️ \(message)") }
        public static func error(_ message: String) { logger.error("❌ \(message)") }
        public static func error(_ error: Error, context: String? = nil) {
            if let context = context {
                logger.error("❌ \(context): \(error.localizedDescription)")
            } else {
                logger.error("❌ \(error.localizedDescription)")
            }
        }
        public static func success(_ message: String) { logger.info("✅ \(message)") }
    }

    /// Search operations logger
    public struct Search {
        private static let logger = Logger(subsystem: "\(bundleIdentifier).Search", category: "General")

        public static func trace(_ message: String) { logger.trace("\(message)") }
        public static func debug(_ message: String) { logger.debug("\(message)") }
        public static func info(_ message: String) { logger.info("\(message)") }
        public static func notice(_ message: String) { logger.notice("\(message)") }
        public static func warning(_ message: String) { logger.warning("⚠️ \(message)") }
        public static func error(_ message: String) { logger.error("❌ \(message)") }
        public static func error(_ error: Error, context: String? = nil) {
            if let context = context {
                logger.error("❌ \(context): \(error.localizedDescription)")
            } else {
                logger.error("❌ \(error.localizedDescription)")
            }
        }
        public static func success(_ message: String) { logger.info("✅ \(message)") }
        public static func performance(_ metric: String, value: Any) {
            logger.debug("⏱️ \(metric): \(String(describing: value))")
        }
    }

    /// Playback operations logger
    public struct Playback {
        private static let logger = Logger(subsystem: "\(bundleIdentifier).Playback", category: "General")

        public static func trace(_ message: String) { logger.trace("\(message)") }
        public static func debug(_ message: String) { logger.debug("\(message)") }
        public static func info(_ message: String) { logger.info("\(message)") }
        public static func notice(_ message: String) { logger.notice("\(message)") }
        public static func warning(_ message: String) { logger.warning("⚠️ \(message)") }
        public static func error(_ message: String) { logger.error("❌ \(message)") }
        public static func error(_ error: Error, context: String? = nil) {
            if let context = context {
                logger.error("❌ \(context): \(error.localizedDescription)")
            } else {
                logger.error("❌ \(error.localizedDescription)")
            }
        }
        public static func success(_ message: String) { logger.info("✅ \(message)") }
        public static func userAction(_ action: String) { logger.info("👤 \(action)") }
        public static func stateChange(from: String, to: String) {
            logger.info("🔄 State: \(from) → \(to)")
        }
    }

    /// UI operations logger
    public struct UI {
        private static let logger = Logger(subsystem: "\(bundleIdentifier).UI", category: "UserAction")

        public static func trace(_ message: String) { logger.trace("\(message)") }
        public static func debug(_ message: String) { logger.debug("\(message)") }
        public static func info(_ message: String) { logger.info("\(message)") }
        public static func notice(_ message: String) { logger.notice("\(message)") }
        public static func warning(_ message: String) { logger.warning("⚠️ \(message)") }
        public static func error(_ message: String) { logger.error("❌ \(message)") }
        public static func error(_ error: Error, context: String? = nil) {
            if let context = context {
                logger.error("❌ \(context): \(error.localizedDescription)")
            } else {
                logger.error("❌ \(error.localizedDescription)")
            }
        }
        public static func userAction(_ action: String) { logger.info("👤 \(action)") }
    }

    /// Network operations logger
    public struct Network {
        private static let logger = Logger(subsystem: "\(bundleIdentifier).Network", category: "API")

        public static func trace(_ message: String) { logger.trace("\(message)") }
        public static func debug(_ message: String) { logger.debug("\(message)") }
        public static func info(_ message: String) { logger.info("\(message)") }
        public static func notice(_ message: String) { logger.notice("\(message)") }
        public static func warning(_ message: String) { logger.warning("⚠️ \(message)") }
        public static func error(_ message: String) { logger.error("❌ \(message)") }
        public static func error(_ error: Error, context: String? = nil) {
            if let context = context {
                logger.error("❌ \(context): \(error.localizedDescription)")
            } else {
                logger.error("❌ \(error.localizedDescription)")
            }
        }
        public static func apiCall(_ endpoint: String) { logger.debug("🌐 API: \(endpoint)") }
    }

    /// AI/Persona operations logger
    public struct AI {
        private static let logger = Logger(subsystem: "\(bundleIdentifier).AI", category: "General")

        public static func trace(_ message: String) { logger.trace("\(message)") }
        public static func debug(_ message: String) { logger.debug("\(message)") }
        public static func info(_ message: String) { logger.info("\(message)") }
        public static func notice(_ message: String) { logger.notice("\(message)") }
        public static func warning(_ message: String) { logger.warning("⚠️ \(message)") }
        public static func error(_ message: String) { logger.error("❌ \(message)") }
        public static func error(_ error: Error, context: String? = nil) {
            if let context = context {
                logger.error("❌ \(context): \(error.localizedDescription)")
            } else {
                logger.error("❌ \(error.localizedDescription)")
            }
        }
    }

    /// Session management logger
    public struct Session {
        private static let logger = Logger(subsystem: "\(bundleIdentifier).Session", category: "General")

        public static func trace(_ message: String) { logger.trace("\(message)") }
        public static func debug(_ message: String) { logger.debug("\(message)") }
        public static func info(_ message: String) { logger.info("\(message)") }
        public static func notice(_ message: String) { logger.notice("\(message)") }
        public static func warning(_ message: String) { logger.warning("⚠️ \(message)") }
        public static func error(_ message: String) { logger.error("❌ \(message)") }
        public static func error(_ error: Error, context: String? = nil) {
            if let context = context {
                logger.error("❌ \(context): \(error.localizedDescription)")
            } else {
                logger.error("❌ \(error.localizedDescription)")
            }
        }
    }

    /// General purpose logger
    public struct General {
        private static let logger = Logger(subsystem: "\(bundleIdentifier).General", category: "General")

        public static func trace(_ message: String) { logger.trace("\(message)") }
        public static func debug(_ message: String) { logger.debug("\(message)") }
        public static func info(_ message: String) { logger.info("\(message)") }
        public static func notice(_ message: String) { logger.notice("\(message)") }
        public static func warning(_ message: String) { logger.warning("⚠️ \(message)") }
        public static func error(_ message: String) { logger.error("❌ \(message)") }
        public static func error(_ error: Error, context: String? = nil) {
            if let context = context {
                logger.error("❌ \(context): \(error.localizedDescription)")
            } else {
                logger.error("❌ \(error.localizedDescription)")
            }
        }
    }

    // Convenience type aliases for cleaner code
    public static let musicKit = MusicKit.self
    public static let auth = Auth.self
    public static let search = Search.self
    public static let playback = Playback.self
    public static let ui = UI.self
    public static let network = Network.self
    public static let ai = AI.self
    public static let session = Session.self
    public static let general = General.self
}

// MARK: - Usage Examples

/*
 Examples of how to use the logging system:

 // Basic logging
 B2BLog.musicKit.info("Starting music search")
 B2BLog.auth.debug("Checking authorization status")
 B2BLog.playback.error("Failed to play song")

 // Error logging with context
 B2BLog.auth.error(error, context: "requestAuthorization")

 // Performance logging
 B2BLog.search.performance("searchDuration", value: 1.5)

 // User actions
 B2BLog.playback.userAction("Play song")
 B2BLog.ui.userAction("Opened settings")

 // State changes
 B2BLog.playback.stateChange(from: "idle", to: "playing")

 // API calls
 B2BLog.network.apiCall("MusicCatalogSearchRequest")

 // Success messages
 B2BLog.musicKit.success("Song added to queue")
 */