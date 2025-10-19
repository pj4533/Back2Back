//
//  FileExportService.swift
//  Back2Back
//
//  Created on 2025-10-19.
//  Utility service for creating and managing temporary file exports
//

import Foundation
import OSLog

/// Service for creating temporary files for export and sharing
/// Handles file lifecycle: creation, sharing, and automatic cleanup
@MainActor
final class FileExportService {

    // MARK: - Export Format

    enum ExportFormat {
        case text
        case json
        case combined

        var fileExtension: String {
            switch self {
            case .text:
                return "txt"
            case .json:
                return "json"
            case .combined:
                return "txt"
            }
        }

        var contentType: String {
            switch self {
            case .text, .combined:
                return "text/plain"
            case .json:
                return "application/json"
            }
        }
    }

    // MARK: - Export Error

    enum ExportError: Error, LocalizedError {
        case failedToCreateFile
        case failedToWriteData
        case invalidData

        var errorDescription: String? {
            switch self {
            case .failedToCreateFile:
                return "Failed to create temporary file"
            case .failedToWriteData:
                return "Failed to write data to file"
            case .invalidData:
                return "Invalid data for export"
            }
        }
    }

    // MARK: - Properties

    /// Temporary directory for export files
    private let tempDirectory: URL

    /// Track created files for cleanup
    private var createdFiles: Set<URL> = []

    // MARK: - Initialization

    init() {
        // Use a dedicated subdirectory in temp for better organization
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Back2BackExports", isDirectory: true)

        // Create the directory if it doesn't exist
        try? FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        // Clean up any old export files on initialization
        cleanupOldFiles()
    }

    // MARK: - File Creation

    /// Create a temporary file with the given content
    /// - Parameters:
    ///   - content: String content to write
    ///   - filename: Base filename (without extension)
    ///   - format: Export format (determines extension and encoding)
    /// - Returns: URL of the created file
    func createTemporaryFile(
        content: String,
        filename: String,
        format: ExportFormat
    ) throws -> URL {
        guard !content.isEmpty else {
            throw ExportError.invalidData
        }

        // Create unique filename with timestamp to avoid collisions
        let timestamp = Date().formatted(.iso8601.dateSeparator(.dash))
        let sanitizedFilename = sanitizeFilename(filename)
        let fullFilename = "\(sanitizedFilename)_\(timestamp).\(format.fileExtension)"

        let fileURL = tempDirectory.appendingPathComponent(fullFilename)

        // Write content to file
        guard let data = content.data(using: .utf8) else {
            B2BLog.general.error("Failed to encode content as UTF-8")
            throw ExportError.invalidData
        }

        do {
            try data.write(to: fileURL, options: .atomic)
            createdFiles.insert(fileURL)

            B2BLog.general.info("Created temporary file: \(fileURL.lastPathComponent)")
            return fileURL
        } catch {
            B2BLog.general.error("Failed to write file: \(error.localizedDescription)")
            throw ExportError.failedToWriteData
        }
    }

    /// Create multiple temporary files for batch export
    /// - Parameter exports: Array of (content, filename, format) tuples
    /// - Returns: Array of created file URLs
    func createTemporaryFiles(
        exports: [(content: String, filename: String, format: ExportFormat)]
    ) throws -> [URL] {
        var urls: [URL] = []

        for export in exports {
            let url = try createTemporaryFile(
                content: export.content,
                filename: export.filename,
                format: export.format
            )
            urls.append(url)
        }

        return urls
    }

    // MARK: - Cleanup

    /// Clean up a specific file
    /// - Parameter url: URL of file to remove
    func cleanupFile(_ url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            createdFiles.remove(url)
            B2BLog.general.debug("Cleaned up file: \(url.lastPathComponent)")
        } catch {
            B2BLog.general.warning("Failed to cleanup file: \(error.localizedDescription)")
        }
    }

    /// Clean up multiple files
    /// - Parameter urls: Array of file URLs to remove
    func cleanupFiles(_ urls: [URL]) {
        urls.forEach { cleanupFile($0) }
    }

    /// Clean up all tracked files
    func cleanupAllTrackedFiles() {
        createdFiles.forEach { url in
            try? FileManager.default.removeItem(at: url)
        }
        createdFiles.removeAll()
        B2BLog.general.debug("Cleaned up all tracked export files")
    }

    /// Clean up old export files (older than 1 hour)
    private func cleanupOldFiles() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: tempDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else {
            return
        }

        let oneHourAgo = Date().addingTimeInterval(-3600)

        for fileURL in files {
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
                  let creationDate = attributes[.creationDate] as? Date,
                  creationDate < oneHourAgo else {
                continue
            }

            try? FileManager.default.removeItem(at: fileURL)
            B2BLog.general.debug("Cleaned up old export file: \(fileURL.lastPathComponent)")
        }
    }

    // MARK: - Helpers

    /// Sanitize filename to remove invalid characters
    private func sanitizeFilename(_ filename: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        return filename
            .components(separatedBy: invalidCharacters)
            .joined(separator: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
