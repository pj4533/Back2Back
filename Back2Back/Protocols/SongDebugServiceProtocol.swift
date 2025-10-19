//
//  SongDebugServiceProtocol.swift
//  Back2Back
//
//  Created on 2025-10-19.
//  Protocol for song debugging service (Issue #87)
//

import Foundation

@MainActor
protocol SongDebugServiceProtocol {
    var debugInfo: [UUID: SongDebugInfo] { get }

    func logDebugInfo(_ info: SongDebugInfo)
    func getDebugInfo(for sessionSongId: UUID) -> SongDebugInfo?
    func clearAllDebugInfo()
    func getAllDebugInfo() -> [SongDebugInfo]
}
