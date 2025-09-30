//
//  SourcesListView.swift
//  Back2Back
//
//  Created on 2025-09-30.
//  Extracted from PersonaDetailView as part of Phase 1 refactoring (#20)
//

import SwiftUI

struct SourcesListView: View {
    let sources: [String]
    @Environment(\.dismiss) var dismiss

    var body: some View {
        List(sources, id: \.self) { source in
            Link(destination: URL(string: source) ?? URL(string: "https://openai.com")!) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(extractDomain(from: source))
                            .font(.headline)
                        Text(source)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(.blue)
                }
            }
        }
        .navigationTitle("Web Sources")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }

    private func extractDomain(from urlString: String) -> String {
        guard let url = URL(string: urlString),
              let host = url.host else {
            return urlString
        }
        return host.replacingOccurrences(of: "www.", with: "")
    }
}
