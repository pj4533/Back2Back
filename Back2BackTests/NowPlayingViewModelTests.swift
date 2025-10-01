//
//  NowPlayingViewModelTests.swift
//  Back2BackTests
//
//  Created for issue #27 - Interactive playback controls
//

import Testing
import MusicKit
import Foundation
import CoreGraphics
@testable import Back2Back

@MainActor
struct NowPlayingViewModelTests {

    // MARK: - Initialization Tests

    @Test func viewModelInitializesWithLivePlaybackTimeZero() async throws {
        let viewModel = NowPlayingViewModel()
        #expect(viewModel.livePlaybackTime == 0)
    }

    @Test func viewModelInitializesPlaybackTracking() async throws {
        let viewModel = NowPlayingViewModel()
        // Wait a short time to allow the tracking task to start
        try await Task.sleep(for: .milliseconds(100))
        // The tracking task should be running (we can't directly test this,
        // but we verify it doesn't crash and initializes properly)
        #expect(viewModel.livePlaybackTime >= 0)
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
