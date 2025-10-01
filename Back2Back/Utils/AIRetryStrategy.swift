//
//  AIRetryStrategy.swift
//  Back2Back
//
//  Created on 2025-09-30.
//  Extracted from SessionViewModel as part of Phase 3 refactoring (#23)
//

import Foundation
import OSLog

/// Provides retry logic for AI operations with consistent error handling
@MainActor
final class AIRetryStrategy {

    /// Execute an operation with automatic retry on failure
    /// - Parameters:
    ///   - operation: The async operation to execute
    ///   - retryOperation: The retry operation to execute if first attempt fails
    ///   - maxAttempts: Maximum number of attempts (default: 10)
    ///   - shouldRetry: Optional closure to determine if retry should occur based on result
    ///   - onRetry: Optional callback invoked before retry attempt
    /// - Returns: The result of the operation
    /// - Throws: The error from the last failed attempt
    static func executeWithRetry<T>(
        operation: @escaping () async throws -> T?,
        retryOperation: (() async throws -> T?)? = nil,
        maxAttempts: Int = 10,
        shouldRetry: ((T?) -> Bool)? = nil,
        onRetry: (() async -> Void)? = nil
    ) async throws -> T? {
        B2BLog.ai.debug("Starting retry strategy with max attempts: \(maxAttempts)")

        // First attempt
        do {
            let result = try await operation()

            // Check if result is valid or if we should retry
            if let shouldRetryCheck = shouldRetry {
                if shouldRetryCheck(result) {
                    B2BLog.ai.warning("⚠️ First attempt returned invalid result, retrying...")
                    return try await performRetries(
                        retryOperation: retryOperation ?? operation,
                        remainingAttempts: maxAttempts - 1,
                        attemptNumber: 2,
                        onRetry: onRetry
                    )
                }
            }

            // Check if result is nil and we should retry
            if result == nil && maxAttempts > 1 {
                B2BLog.ai.warning("⚠️ First attempt returned nil, retrying...")
                return try await performRetries(
                    retryOperation: retryOperation ?? operation,
                    remainingAttempts: maxAttempts - 1,
                    attemptNumber: 2,
                    onRetry: onRetry
                )
            }

            B2BLog.ai.debug("✅ First attempt succeeded")
            return result
        } catch {
            // First attempt threw an error
            B2BLog.ai.warning("⚠️ First attempt failed with error: \(error)")

            if maxAttempts > 1 {
                return try await performRetries(
                    retryOperation: retryOperation ?? operation,
                    remainingAttempts: maxAttempts - 1,
                    attemptNumber: 2,
                    onRetry: onRetry
                )
            } else {
                throw error
            }
        }
    }

    /// Execute retry operations with multiple attempts
    private static func performRetries<T>(
        retryOperation: () async throws -> T?,
        remainingAttempts: Int,
        attemptNumber: Int,
        onRetry: (() async -> Void)?
    ) async throws -> T? {
        guard remainingAttempts > 0 else {
            B2BLog.ai.error("❌ All retry attempts exhausted - giving up")
            return nil
        }

        // Call optional pre-retry callback
        if let onRetry = onRetry {
            await onRetry()
        }

        do {
            B2BLog.ai.info("🔄 Retry attempt \(attemptNumber) of maximum attempts")
            let retryResult = try await retryOperation()

            if retryResult != nil {
                B2BLog.ai.info("✅ Retry attempt \(attemptNumber) succeeded")
                return retryResult
            } else {
                B2BLog.ai.warning("⚠️ Retry attempt \(attemptNumber) returned nil, continuing...")

                // Recursive retry with remaining attempts
                return try await performRetries(
                    retryOperation: retryOperation,
                    remainingAttempts: remainingAttempts - 1,
                    attemptNumber: attemptNumber + 1,
                    onRetry: onRetry
                )
            }
        } catch {
            B2BLog.ai.warning("⚠️ Retry attempt \(attemptNumber) failed with error: \(error)")

            if remainingAttempts > 1 {
                // Continue with remaining attempts
                return try await performRetries(
                    retryOperation: retryOperation,
                    remainingAttempts: remainingAttempts - 1,
                    attemptNumber: attemptNumber + 1,
                    onRetry: onRetry
                )
            } else {
                B2BLog.ai.error("❌ Final retry attempt failed - giving up")
                throw error
            }
        }
    }
}
