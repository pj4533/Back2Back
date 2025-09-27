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
public struct B2BLog {

    // Single subsystem for the entire app
    private static let subsystem = "com.saygoodnight.Back2Back"

    // Categories for filtering
    public enum Category: String {
        case general = "General"
        case musicKit = "MusicKit"
        case auth = "Authentication"
        case search = "Search"
        case playback = "Playback"
        case ui = "UI"
        case network = "Network"
        case ai = "AI"
        case session = "Session"
    }

    // Loggers for each category
    public static let general = Logger(subsystem: subsystem, category: Category.general.rawValue)
    public static let musicKit = Logger(subsystem: subsystem, category: Category.musicKit.rawValue)
    public static let auth = Logger(subsystem: subsystem, category: Category.auth.rawValue)
    public static let search = Logger(subsystem: subsystem, category: Category.search.rawValue)
    public static let playback = Logger(subsystem: subsystem, category: Category.playback.rawValue)
    public static let ui = Logger(subsystem: subsystem, category: Category.ui.rawValue)
    public static let network = Logger(subsystem: subsystem, category: Category.network.rawValue)
    public static let ai = Logger(subsystem: subsystem, category: Category.ai.rawValue)
    public static let session = Logger(subsystem: subsystem, category: Category.session.rawValue)
}

// MARK: - Convenience Extensions

public extension Logger {

    // Standard logging with emoji prefixes
    func trace(_ message: String) {
        self.trace("\(message)")
    }

    func debug(_ message: String) {
        self.debug("\(message)")
    }

    func info(_ message: String) {
        self.info("\(message)")
    }

    func notice(_ message: String) {
        self.notice("\(message)")
    }

    func warning(_ message: String) {
        self.warning("⚠️ \(message)")
    }

    func error(_ message: String) {
        self.error("❌ \(message)")
    }

    func error(_ error: Error, context: String? = nil) {
        if let context = context {
            self.error("❌ \(context): \(error.localizedDescription)")
        } else {
            self.error("❌ \(error.localizedDescription)")
        }
    }

    func success(_ message: String) {
        self.info("✅ \(message)")
    }

    // Special logging methods
    func performance(metric: String, value: Any) {
        self.debug("⏱️ \(metric): \(String(describing: value))")
    }

    func userAction(_ action: String) {
        self.info("👤 \(action)")
    }

    func stateChange(from: String, to: String) {
        self.info("🔄 State: \(from) → \(to)")
    }

    func apiCall(_ endpoint: String) {
        self.debug("🌐 API: \(endpoint)")
    }
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
 B2BLog.search.performance(metric: "searchDuration", value: 1.5)

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