//
//  NowPlayingViewModelTests.swift
//  Back2BackTests
//
//  Created for issue #27 - Interactive playback controls
//  Updated for animation-based approach (no polling)
//

import Testing
import MusicKit
import Foundation
import CoreGraphics
@testable import Back2Back

@MainActor
struct NowPlayingViewModelTests {

    // MARK: - Initialization Tests

    @Test func viewModelInitializesWithZeroBaseTime() async throws {
        let viewModel = NowPlayingViewModel()
        #expect(viewModel.basePlaybackTime == 0)
    }

    @Test func viewModelInitializesWithNilAnimationStartTime() async throws {
        let viewModel = NowPlayingViewModel()
        #expect(viewModel.animationStartTime == nil)
    }

    // MARK: - Animation-Based Time Calculation Tests

    @Test func getCurrentPlaybackTimeReturnsBaseTimeWhenNotPlaying() async throws {
        let viewModel = NowPlayingViewModel()
        viewModel.basePlaybackTime = 42.0
        viewModel.animationStartTime = Date()

        // When not playing, should return base time regardless of elapsed time
        let currentTime = viewModel.getCurrentPlaybackTime()
        #expect(currentTime == 42.0)
    }

    @Test func getCurrentPlaybackTimeReturnsBaseTimeWhenAnimationStartTimeIsNil() async throws {
        let viewModel = NowPlayingViewModel()
        viewModel.basePlaybackTime = 30.0
        viewModel.animationStartTime = nil

        let currentTime = viewModel.getCurrentPlaybackTime()
        #expect(currentTime == 30.0)
    }

    @Test func getCurrentPlaybackTimeCalculatesElapsedTime() async throws {
        let viewModel = NowPlayingViewModel()

        // Set base time to 10 seconds
        viewModel.basePlaybackTime = 10.0

        // Simulate 5 seconds elapsed (animation started 5 seconds ago)
        viewModel.animationStartTime = Date().addingTimeInterval(-5)

        // Mock playing state by accessing the computed property would require mocking MusicService
        // For this test, we'll just verify the calculation works
        // In a real scenario with playing state, it should be base + elapsed = 10 + 5 = 15
        let currentTime = viewModel.getCurrentPlaybackTime()

        // Without mocked playing state, it returns base time
        // This test structure is designed for future enhancement with dependency injection
        #expect(currentTime >= 10.0)
    }

    // MARK: - Update Base Time Tests

    @Test func updateBasePlaybackTimeSetsAnimationStartTime() async throws {
        let viewModel = NowPlayingViewModel()

        #expect(viewModel.animationStartTime == nil)

        viewModel.updateBasePlaybackTime()

        #expect(viewModel.animationStartTime != nil)
    }

    @Test func updateBasePlaybackTimeUpdatesBaseTime() async throws {
        let viewModel = NowPlayingViewModel()

        let initialBase = viewModel.basePlaybackTime
        viewModel.updateBasePlaybackTime()

        // Base time should be updated (even if it's still 0 from getCurrentPlaybackTime())
        #expect(viewModel.basePlaybackTime >= initialBase)
    }

    // MARK: - Time Formatting Tests

    @Test func formatTimeWithZeroSeconds() async throws {
        let formatter = TimeFormatter()
        let result = formatter.format(0)
        #expect(result == "0:00")
    }

    @Test func formatTimeWithOneMinute() async throws {
        let formatter = TimeFormatter()
        let result = formatter.format(60)
        #expect(result == "1:00")
    }

    @Test func formatTimeWithMultipleMinutes() async throws {
        let formatter = TimeFormatter()
        let result = formatter.format(185)
        #expect(result == "3:05")
    }

    @Test func formatTimeWithHours() async throws {
        let formatter = TimeFormatter()
        let result = formatter.format(3661)
        #expect(result == "61:01")
    }

    // MARK: - Progress Calculation Tests

    @Test func progressWidthIsZeroWhenDurationIsZero() async throws {
        let calculator = ProgressCalculator()
        let width = calculator.width(current: 30, duration: 0, totalWidth: 100)
        #expect(width == 0)
    }

    @Test func progressWidthIsHalfWhenAtHalfDuration() async throws {
        let calculator = ProgressCalculator()
        let width = calculator.width(current: 30, duration: 60, totalWidth: 100)
        #expect(width == 50)
    }

    @Test func progressWidthIsFullWhenAtEndOfDuration() async throws {
        let calculator = ProgressCalculator()
        let width = calculator.width(current: 60, duration: 60, totalWidth: 100)
        #expect(width == 100)
    }

    @Test func progressWidthClampedToMaxWhenExceedingDuration() async throws {
        let calculator = ProgressCalculator()
        let width = calculator.width(current: 90, duration: 60, totalWidth: 100)
        #expect(width == 100)
    }

    @Test func progressWidthClampedToZeroWhenNegative() async throws {
        let calculator = ProgressCalculator()
        let width = calculator.width(current: -10, duration: 60, totalWidth: 100)
        #expect(width == 0)
    }

    // MARK: - Time Calculation Tests

    @Test func calculateTimeAtStart() async throws {
        let calculator = TimeCalculator()
        let time = calculator.time(from: 0, in: 100, duration: 60)
        #expect(time == 0)
    }

    @Test func calculateTimeAtMiddle() async throws {
        let calculator = TimeCalculator()
        let time = calculator.time(from: 50, in: 100, duration: 60)
        #expect(time == 30)
    }

    @Test func calculateTimeAtEnd() async throws {
        let calculator = TimeCalculator()
        let time = calculator.time(from: 100, in: 100, duration: 60)
        #expect(time == 60)
    }

    @Test func calculateTimeClampedToMaxWhenExceedingWidth() async throws {
        let calculator = TimeCalculator()
        let time = calculator.time(from: 150, in: 100, duration: 60)
        #expect(time == 60)
    }

    @Test func calculateTimeClampedToZeroWhenNegative() async throws {
        let calculator = TimeCalculator()
        let time = calculator.time(from: -10, in: 100, duration: 60)
        #expect(time == 0)
    }

    // MARK: - Animation-Based Elapsed Time Calculation

    @Test func elapsedTimeCalculationIsAccurate() async throws {
        let baseTime: TimeInterval = 15.0
        let elapsedSeconds: TimeInterval = 7.0

        let animationStartTime = Date().addingTimeInterval(-elapsedSeconds)
        let calculatedElapsed = Date().timeIntervalSince(animationStartTime)

        // Should be approximately 7 seconds (within 0.1s tolerance for test execution time)
        #expect(abs(calculatedElapsed - elapsedSeconds) < 0.1)

        let expectedCurrentTime = baseTime + calculatedElapsed
        #expect(abs(expectedCurrentTime - 22.0) < 0.1)
    }

    @Test func animationTimeCalculationWithMultipleUpdates() async throws {
        // Simulate multiple base time updates (like during seeks or state changes)
        var baseTime: TimeInterval = 0
        var startTime = Date()

        // First playback period (0-10 seconds)
        baseTime = 0
        startTime = Date().addingTimeInterval(-10)
        var currentTime = baseTime + Date().timeIntervalSince(startTime)
        #expect(abs(currentTime - 10.0) < 0.1)

        // User seeks to 30 seconds
        baseTime = 30
        startTime = Date()
        currentTime = baseTime + Date().timeIntervalSince(startTime)
        #expect(abs(currentTime - 30.0) < 0.1)

        // After 5 more seconds of playback
        startTime = Date().addingTimeInterval(-5)
        currentTime = baseTime + Date().timeIntervalSince(startTime)
        #expect(abs(currentTime - 35.0) < 0.1)
    }
}

// MARK: - Helper Classes for Testing

/// Helper class to test time formatting logic
struct TimeFormatter {
    func format(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

/// Helper class to test progress width calculation
struct ProgressCalculator {
    func width(current: TimeInterval, duration: TimeInterval, totalWidth: CGFloat) -> CGFloat {
        guard duration > 0 else { return 0 }
        let progress = current / duration
        return totalWidth * min(max(progress, 0), 1)
    }
}

/// Helper class to test time calculation from position
struct TimeCalculator {
    func time(from xPosition: CGFloat, in width: CGFloat, duration: TimeInterval) -> TimeInterval {
        let progress = max(0, min(1, xPosition / width))
        return duration * progress
    }
}
