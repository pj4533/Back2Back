# Testing Safety - No Network Calls

## OpenAI API Testing Policy

**IMPORTANT**: All tests in this project are designed to NEVER make real network calls to OpenAI's API.

### How It Works

We use **Protocol-Based Dependency Injection** with mock objects:

1. **Production Code Uses Protocols**: ViewModels and Coordinators accept `any AIRecommendationServiceProtocol` instead of concrete `OpenAIClient`
   ```swift
   // PersonasViewModel.swift
   private let aiService: any AIRecommendationServiceProtocol  // Not: OpenAIClient
   ```

2. **Tests Inject Mocks**: Test factory methods inject `MockAIRecommendationService` instead of real client
   ```swift
   func createTestViewModel() -> PersonasViewModel {
       let mockAIService = MockAIRecommendationService()
       return PersonasViewModel(personaService: personaService, aiService: mockAIService)
   }
   ```

3. **Mock Provides Realistic Responses**: `MockAIRecommendationService` returns realistic JSON-like data
   - Song recommendations with actual artist/song names
   - Style guides with proper formatting
   - Direction changes with realistic prompts
   - Configurable error simulation

### Safety Guarantees

- ✅ **Zero network calls possible** - Tests never instantiate real OpenAIClient for AI operations
- ✅ **Proper test isolation** - Each test uses fresh mock with controlled responses
- ✅ **Realistic testing** - Mock responses match actual API response structure
- ✅ **Error testing** - Can simulate API errors without making real calls
- ✅ **Parameter verification** - Mock tracks all calls for assertion

### Architecture

**Protocol-Based Design**:
```
AIRecommendationServiceProtocol (protocol)
├── OpenAIClient (production)
└── MockAIRecommendationService (testing)
```

**Files Using Protocol Injection**:
- `PersonasViewModel` - Accepts `any AIRecommendationServiceProtocol`
- `SessionViewModel` - Accepts `any AIRecommendationServiceProtocol`
- `AISongCoordinator` - Accepts `any AIRecommendationServiceProtocol`

**Mock Implementation**:
- `MockAIRecommendationService.swift` - Full protocol implementation with:
  - Realistic default responses
  - Call tracking for verification
  - Error simulation support
  - Parameter capture for assertions

### Test Categories

**Model Tests** (No dependencies):
- `OpenAIModelsTests` - JSON encoding/decoding only
- `OpenAISongSelectionTests` - Data structure tests only

**Client Tests** (Uses real client, but tests configuration only):
- `OpenAIClientTests` - Tests instantiation and configuration
- Does NOT test network calls (would require API key)

**ViewModel Tests** (Uses mock for complete isolation):
- `PersonasViewModelTests` - Uses `MockAIRecommendationService`
- `SessionViewModelTests` - Uses `MockAIRecommendationService`
- Full coverage of AI interactions without network calls

### Benefits Over Guard Clause Approach

**Old Approach** (Accidentally Safe):
- Tests used real `OpenAIClient` without API key
- Relied on runtime guard clause to prevent network calls
- Real API calls would occur if `OPENAI_API_KEY` was set
- Limited ability to test error scenarios

**New Approach** (Intentionally Safe):
- Tests use mock that cannot make network calls
- Proper dependency injection following best practices
- Complete control over responses and errors
- Can test all code paths including error handling

### Verification

No verification needed - the architecture guarantees safety:
```swift
// Mock implementation has no networking code
class MockAIRecommendationService: AIRecommendationServiceProtocol {
    // Pure in-memory responses, no URLSession
}
```
