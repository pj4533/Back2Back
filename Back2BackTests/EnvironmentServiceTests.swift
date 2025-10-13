import Testing
@testable import Back2Back
import Foundation

@Suite("EnvironmentService Tests")
@MainActor
struct EnvironmentServiceTests {

    @Test("EnvironmentService instances are independent")
    func testIndependentInstances() async throws {
        let instance1 = EnvironmentService()
        let instance2 = EnvironmentService()

        #expect(instance1 !== instance2, "EnvironmentService should create distinct instances")
    }

    @Test("getOpenAIKey returns nil when environment variable is not set")
    func testGetOpenAIKeyReturnsNilWhenNotSet() async throws {
        // This test assumes OPENAI_API_KEY is not set in the test environment
        // In a real scenario, we'd need to mock ProcessInfo or use dependency injection

        let service = EnvironmentService()

        // If the key is set in test environment, this test would need adjustment
        // For now, we're testing the actual behavior
        let key = service.getOpenAIKey()

        // This test may pass or fail depending on whether OPENAI_API_KEY is set
        // In CI/CD, this would typically be nil
        if ProcessInfo.processInfo.environment["OPENAI_API_KEY"] == nil {
            #expect(key == nil, "Should return nil when OPENAI_API_KEY is not set")
        } else {
            #expect(key != nil, "Should return the key when OPENAI_API_KEY is set")
        }
    }

    @Test("getValue returns correct value for existing environment variable")
    func testGetValueForExistingVariable() async throws {
        let service = EnvironmentService()

        // PATH should always exist
        let path = service.getValue(for: "PATH")
        #expect(path != nil, "PATH environment variable should exist")
        #expect(!path!.isEmpty, "PATH should not be empty")
    }

    @Test("getValue returns nil for non-existent environment variable")
    func testGetValueForNonExistentVariable() async throws {
        let service = EnvironmentService()

        let value = service.getValue(for: "DEFINITELY_DOES_NOT_EXIST_VARIABLE_12345")
        #expect(value == nil, "Should return nil for non-existent variable")
    }

    @Test("isConfiguredForOpenAI returns false when API key is not set")
    func testIsConfiguredForOpenAIWhenNotSet() async throws {
        let service = EnvironmentService()

        // This depends on whether OPENAI_API_KEY is set in test environment
        if ProcessInfo.processInfo.environment["OPENAI_API_KEY"] == nil {
            #expect(!service.isConfiguredForOpenAI, "Should return false when API key is not set")
        } else {
            #expect(service.isConfiguredForOpenAI, "Should return true when API key is set")
        }
    }

    @Test("getValue handles empty string keys")
    func testGetValueWithEmptyKey() async throws {
        let service = EnvironmentService()

        let value = service.getValue(for: "")
        #expect(value == nil, "Should return nil for empty key")
    }

    @Test("Multiple getValue calls work correctly")
    func testMultipleGetValueCalls() async throws {
        let service = EnvironmentService()

        // Test multiple calls with different keys
        let path = service.getValue(for: "PATH")
        let home = service.getValue(for: "HOME")
        let user = service.getValue(for: "USER")
        let nonExistent = service.getValue(for: "NON_EXISTENT_KEY_XYZ")

        // PATH should exist
        #expect(path != nil, "PATH should exist")

        // HOME typically exists on Unix systems
        if ProcessInfo.processInfo.environment["HOME"] != nil {
            #expect(home != nil, "HOME should exist when set")
        }

        // Non-existent should be nil
        #expect(nonExistent == nil, "Non-existent key should return nil")
    }

    @Test("getOpenAIKey consistency")
    func testGetOpenAIKeyConsistency() async throws {
        let service = EnvironmentService()

        // Multiple calls should return the same result
        let key1 = service.getOpenAIKey()
        let key2 = service.getOpenAIKey()
        let key3 = service.getOpenAIKey()

        #expect(key1 == key2, "Repeated calls should return consistent results")
        #expect(key2 == key3, "Repeated calls should return consistent results")
    }
}
