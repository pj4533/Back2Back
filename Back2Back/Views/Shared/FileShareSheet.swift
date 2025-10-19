//
//  FileShareSheet.swift
//  Back2Back
//
//  Created on 2025-10-19.
//  Enhanced share sheet for file exports with proper cleanup
//

import SwiftUI
import UIKit
import OSLog

/// Enhanced share sheet that handles file URLs properly and performs cleanup
struct FileShareSheet: UIViewControllerRepresentable {

    // MARK: - Properties

    /// File URLs to share
    let fileURLs: [URL]

    /// Optional completion handler called when sharing completes or is cancelled
    let onComplete: (() -> Void)?

    // MARK: - Initialization

    init(fileURLs: [URL], onComplete: (() -> Void)? = nil) {
        self.fileURLs = fileURLs
        self.onComplete = onComplete
    }

    init(fileURL: URL, onComplete: (() -> Void)? = nil) {
        self.fileURLs = [fileURL]
        self.onComplete = onComplete
    }

    // MARK: - UIViewControllerRepresentable

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: fileURLs,
            applicationActivities: nil
        )

        // Set completion handler
        controller.completionWithItemsHandler = { activityType, completed, returnedItems, error in
            if let error = error {
                B2BLog.general.error("Share failed: \(error.localizedDescription)")
            } else if completed {
                B2BLog.general.info("Share completed with activity: \(activityType?.rawValue ?? "unknown")")
            } else {
                B2BLog.general.debug("Share cancelled")
            }

            // Call completion handler on main thread
            DispatchQueue.main.async {
                onComplete?()
            }
        }

        // Configure for iPad (popover presentation)
        if let popover = controller.popoverPresentationController {
            popover.sourceView = UIView()
            popover.permittedArrowDirections = []
        }

        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}

// MARK: - Export Format Selection Sheet

/// Action sheet for selecting export format
struct ExportFormatSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onSelectFormat: (FileExportService.ExportFormat) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    FormatButton(
                        format: .text,
                        title: "Text Report",
                        subtitle: "Human-readable debug report (.txt)",
                        icon: "doc.text",
                        onSelect: onSelectFormat
                    )

                    FormatButton(
                        format: .json,
                        title: "JSON Data",
                        subtitle: "Structured data export (.json)",
                        icon: "curlybraces",
                        onSelect: onSelectFormat
                    )

                    FormatButton(
                        format: .combined,
                        title: "Combined Report",
                        subtitle: "Both text and JSON in one file (.txt)",
                        icon: "doc.on.doc",
                        onSelect: onSelectFormat
                    )
                } header: {
                    Text("Export Format")
                } footer: {
                    Text("Select the format for exporting debug information. Text format is human-readable, JSON is machine-parsable, and Combined includes both.")
                }
            }
            .navigationTitle("Export Debug Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Format Button

private struct FormatButton: View {
    let format: FileExportService.ExportFormat
    let title: String
    let subtitle: String
    let icon: String
    let onSelect: (FileExportService.ExportFormat) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button {
            onSelect(format)
            dismiss()
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Preview

#Preview("Export Format Sheet") {
    ExportFormatSheet { format in
        print("Selected format: \(format)")
    }
}
