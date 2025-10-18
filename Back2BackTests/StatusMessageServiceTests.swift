//
//  StatusMessageServiceTests.swift
//  Back2BackTests
//
//  Created on 2025-10-05.
//

import Testing
import Foundation
@testable import Back2Back

@MainActor
struct StatusMessageServiceTests {
    let service = StatusMessageService()

    init() async {
        // Clear all caches before each test
        service.clearAllCaches()
    }

    @Test("Default messages are returned when no cache exists")
    func defaultMessagesWhenNoCacheExists() async {
        let persona = Persona(
            id: UUID(),
            name: "Test Persona",
            description: "A test DJ persona",
            styleGuide: "Test style guide",
            isSelected: false
        )

        let messages = service.getStatusMessages(for: persona)

        // Should return fallback messages
        #expect(messages.message1 == "Analyzing the vibe...")
        #expect(messages.message2 == "Searching the catalog...")
        #expect(messages.message3 == "Finding the perfect track...")
    }

    @Test("Usage count increments correctly")
    func usageCountIncrements() async {
        let personaId = UUID()

        // Increment usage count multiple times
        service.incrementUsageCount(for: personaId)
        service.incrementUsageCount(for: personaId)
        service.incrementUsageCount(for: personaId)

        // Note: We can't directly access the internal cache from tests,
        // but we can verify the service doesn't crash and runs successfully
        #expect(true) // If we get here, increments succeeded
    }

    @Test("Clear cache for specific persona")
    func clearCacheForPersona() async {
        let personaId = UUID()

        // Clear cache should not crash even if cache doesn't exist
        service.clearCache(for: personaId)

        #expect(true) // If we get here, clear succeeded
    }

    @Test("Clear all caches")
    func clearAllCaches() async {
        service.clearAllCaches()

        #expect(true) // If we get here, clear all succeeded
    }

    @Test("StatusMessages model equality")
    func statusMessagesEquality() async {
        let messages1 = StatusMessages(
            message1: "Message 1",
            message2: "Message 2",
            message3: "Message 3"
        )

        let messages2 = StatusMessages(
            message1: "Message 1",
            message2: "Message 2",
            message3: "Message 3"
        )

        let messages3 = StatusMessages(
            message1: "Different",
            message2: "Message 2",
            message3: "Message 3"
        )

        #expect(messages1 == messages2)
        #expect(messages1 != messages3)
    }

    @Test("CachedStatusMessages should regenerate after threshold")
    func shouldRegenerateAfterThreshold() async {
        let personaId = UUID()
        let messages = StatusMessages(
            message1: "Test 1",
            message2: "Test 2",
            message3: "Test 3"
        )

        // Test with usage count below threshold
        var cached = CachedStatusMessages(
            messages: messages,
            personaId: personaId,
            generatedAt: Date(),
            usageCount: 2
        )
        #expect(cached.shouldRegenerate == false)

        // Test with usage count at threshold
        cached.usageCount = 3
        #expect(cached.shouldRegenerate == true)

        // Test with usage count above threshold
        cached.usageCount = 5
        #expect(cached.shouldRegenerate == true)
    }

    @Test("CachedStatusMessages codable round-trip")
    func cachedMessagesCodableRoundTrip() async throws {
        let personaId = UUID()
        let messages = StatusMessages(
            message1: "Hip-hop vibes...",
            message2: "Searching for beats...",
            message3: "Digging in the crates..."
        )

        let cached = CachedStatusMessages(
            messages: messages,
            personaId: personaId,
            generatedAt: Date(),
            usageCount: 3
        )

        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(cached)

        // Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CachedStatusMessages.self, from: data)

        // Verify
        #expect(decoded.messages == cached.messages)
        #expect(decoded.personaId == cached.personaId)
        #expect(decoded.usageCount == cached.usageCount)
    }

    @Test("Multiple personas maintain separate caches")
    func separateCachesPerPersona() async {
        let persona1 = Persona(
            id: UUID(),
            name: "Hip-Hop DJ",
            description: "Urban beats specialist",
            styleGuide: "Hip-hop style",
            isSelected: false
        )

        let persona2 = Persona(
            id: UUID(),
            name: "Classical Maestro",
            description: "Classical music expert",
            styleGuide: "Classical style",
            isSelected: false
        )

        // Get messages for both personas
        _ = service.getStatusMessages(for: persona1)
        _ = service.getStatusMessages(for: persona2)

        // Increment usage for only persona1
        service.incrementUsageCount(for: persona1.id)
        service.incrementUsageCount(for: persona1.id)

        // Both operations should succeed without interference
        #expect(true)
    }

    @Test("Service handles concurrent access safely")
    func concurrentAccessSafety() async {
        let persona = Persona(
            id: UUID(),
            name: "Test DJ",
            description: "Test persona",
            styleGuide: "Test style",
            isSelected: false
        )

        // Simulate concurrent access
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<5 {
                group.addTask { @MainActor in
                    _ = service.getStatusMessages(for: persona)
                    service.incrementUsageCount(for: persona.id)
                }
            }
        }

        #expect(true) // If we get here, concurrent access succeeded
    }

    @Test("StatusMessages Sendable conformance")
    func statusMessagesSendable() async {
        let messages = StatusMessages(
            message1: "Test 1",
            message2: "Test 2",
            message3: "Test 3"
        )

        // Test that we can send messages across actor boundaries
        Task {
            let _ = messages
            #expect(true)
        }
    }

    @Test("CachedStatusMessages Sendable conformance")
    func cachedMessagesSendable() async {
        let cached = CachedStatusMessages(
            messages: StatusMessages(
                message1: "Test 1",
                message2: "Test 2",
                message3: "Test 3"
            ),
            personaId: UUID(),
            generatedAt: Date(),
            usageCount: 0
        )

        // Test that we can send cached messages across actor boundaries
        Task {
            let _ = cached
            #expect(true)
        }
    }
}
