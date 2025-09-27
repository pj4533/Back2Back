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

    // Loggers for each category
    public static let general = Logger(subsystem: subsystem, category: "General")
    public static let musicKit = Logger(subsystem: subsystem, category: "MusicKit")
    public static let auth = Logger(subsystem: subsystem, category: "Authentication")
    public static let search = Logger(subsystem: subsystem, category: "Search")
    public static let playback = Logger(subsystem: subsystem, category: "Playback")
    public static let ui = Logger(subsystem: subsystem, category: "UI")
    public static let network = Logger(subsystem: subsystem, category: "Network")
    public static let ai = Logger(subsystem: subsystem, category: "AI")
    public static let session = Logger(subsystem: subsystem, category: "Session")
}

// MARK: - Usage Examples

/*
 Examples of how to use the logging system:

 // Basic logging
 B2BLog.musicKit.info("Starting music search")
 B2BLog.auth.debug("Checking authorization status")
 B2BLog.playback.error("❌ Failed to play song")
 B2BLog.auth.warning("⚠️ Authorization not determined")
 B2BLog.musicKit.info("✅ Song added to queue")

 // With string interpolation
 B2BLog.search.debug("⏱️ searchDuration: \(duration)")
 B2BLog.ui.info("👤 User opened settings")
 B2BLog.playback.info("🔄 State: idle → playing")
 B2BLog.network.debug("🌐 API: MusicCatalogSearchRequest")
 */