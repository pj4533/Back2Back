# Testing Safety - No Network Calls

## OpenAI API Testing Policy

**IMPORTANT**: All tests in this project are designed to NEVER make real network calls to OpenAI's API.

### How It Works

1. **Tests run without API key**: Tests do NOT set `OPENAI_API_KEY` environment variable
2. **Fail-safe in networking layer**: `OpenAINetworking.responses()` checks for API key BEFORE making network calls:
   ```swift
   guard let apiKey = client.apiKey, !apiKey.isEmpty else {
       throw OpenAIError.apiKeyMissing  // ← Throws before URLSession.dataTask
   }
   ```
3. **No mock needed**: Because the guard clause prevents network calls, we don't need complex mocking

### Safety Guarantees

- ✅ No network calls are made during testing
- ✅ Even if tests call `client.selectNextSong()` or `client.generatePersonaStyleGuide()`, they fail with `OpenAIError.apiKeyMissing`
- ✅ Tests that need to call these methods handle the error gracefully (like `PersonasViewModelTests.testRegenerateStyleGuide`)

### What If OPENAI_API_KEY Is Set?

**WARNING**: If you run tests with `OPENAI_API_KEY` environment variable set, REAL API calls WILL be made and you WILL be charged by OpenAI.

To prevent accidental API calls:
1. Never export `OPENAI_API_KEY` in your shell
2. Don't add it to test schemes in Xcode
3. CI/CD should NOT set this variable for test runs

### Test Categories

**Model Tests** (No network risk):
- `OpenAIModelsTests` - JSON encoding/decoding only
- `OpenAISongSelectionTests` - Data structure tests only

**Client Tests** (Protected by isConfigured check):
- `OpenAIClientTests` - Only tests behavior when API key is missing
- Wraps network-calling tests in `if !client.isConfigured`

**Integration Tests** (Tests call OpenAI methods but fail safely):
- `PersonasViewModelTests` - Calls `regenerateStyleGuide()` but catches errors
- `SessionViewModelTests` - Uses OpenAIClient but never triggers network calls
- These tests verify the code doesn't crash when API is unavailable

### Verification

Run this to verify no API key is set during tests:
```swift
#expect(ProcessInfo.processInfo.environment["OPENAI_API_KEY"] == nil, "API key should not be set during tests")
```

This assertion can be added to any test suite's init or setup method.
