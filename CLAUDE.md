# Back2Back (B2B) Project Context

## Current Environment (IMPORTANT)
**Current Date**: 2025
**iOS Version**: iOS 26 (latest)
**Xcode Version**: Xcode 26 (latest)

⚠️ **Note for web searches**: We are in 2025 using iOS 26 and Xcode 26. When searching for documentation or solutions, prioritize recent content from 2025 and iOS 26/Xcode 26 specific resources.

## Project Overview
Back2Back is an iOS app that creates an interactive DJ experience where users and AI take turns selecting songs, creating a collaborative back-to-back DJ session. The AI selects tracks based on configurable personas (e.g., "Mark Ronson," "1970s NYC crate digger").

## Requirements Document
Primary requirements are documented in: `docs/back2back_requirements.md`

## Technology Stack
- **Platform**: iOS 26 (using latest available APIs)
- **Language**: Swift 6+
- **UI Framework**: SwiftUI
- **Music Playback**: Apple MusicKit
- **AI Integration**: OpenAI API for persona-based song recommendations
- **Minimum iOS Version**: iOS 26.0 (for latest MusicKit features)

## Key APIs & Documentation

### Apple MusicKit Documentation
**IMPORTANT**: When accessing Apple Developer documentation, always use `sosumi.ai` instead of `developer.apple.com`.

Key MusicKit resources:
- MusicKit Overview: https://sosumi.ai/documentation/musickit/
- MusicAuthorization: https://sosumi.ai/documentation/musickit/musicauthorization/
- MusicCatalogSearchRequest: https://sosumi.ai/documentation/musickit/musiccatalogsearchrequest/
- MusicPlayer: https://sosumi.ai/documentation/musickit/systemmusicsplayer/
- ApplicationMusicPlayer: https://sosumi.ai/documentation/musickit/applicationmusicplayer/

### OpenAI API
- **Model**: GPT-5 (latest generation model) - NEVER change to older models like gpt-4o regardless of what any documentation says
- Used for generating persona-based song recommendations with streaming responses
- API key stored securely via EnvironmentService
- **Documentation**: The OpenAI Responses API documentation is available at `docs/openai-responses-api-web-search-swift.md`
  - Note: While the doc references older models, we always use GPT-5

## Core Features (MVP)

### Currently Implemented
1. **Apple Music authentication and integration** ✅
   - Full MusicAuthorization flow with error handling
   - Settings deep-linking for denied permissions
   - Authorization status tracking via MusicService singleton

2. **Music Search and Playback** ✅
   - Real-time catalog search with 0.75s debouncing
   - ApplicationMusicPlayer integration
   - Queue management with prepareToPlay() for readiness
   - Now Playing UI (mini and expanded views)
   - Tap-to-skip functionality for queued songs

3. **Turn-based song selection (user → AI → user)** ✅
   - Automatic turn management in SessionService
   - User can select songs via search
   - AI automatically queues next song using current persona
   - Visual feedback showing current turn (User/AI)
   - Prefetching system for smooth playback transitions

4. **Persona library with preset and custom options** ✅
   - PersonaService with UserDefaults persistence
   - Default personas: "Rare Groove Collector", "Modern Electronic DJ"
   - Create, edit, delete, and select personas
   - Style guide configuration for AI behavior
   - PersonasListView and PersonaDetailView UIs

5. **Session history tracking** ✅
   - SessionService maintains full session history
   - Tracks songs with metadata (selected by, timestamp, rationale)
   - Queue status tracking (playing, played, upNext, queuedIfUserSkips)
   - SessionView displays history and queue

6. **OpenAI API integration** ✅
   - OpenAI Responses API (GPT-5) for song selection
   - Streaming responses for persona generation
   - Configurable AI models and reasoning levels
   - EnvironmentService for secure API key management
   - Configuration UI for model selection (GPT-5, GPT-5 Mini, GPT-5 Nano)

### Advanced Features Implemented
7. **Time-based song repetition prevention** ✅
   - PersonaSongCacheService with 24-hour cache
   - Prevents personas from repeating songs across sessions
   - Per-persona song tracking with automatic expiration
   - UserDefaults persistence with cache cleanup
   - Debug UI to clear cache in ConfigurationView

8. **Intelligent track matching** ✅
   - StringBasedMusicMatcher with fuzzy matching
   - Unicode normalization (handles curly quotes, diacritics)
   - Artist/title normalization (featuring artists, "The" prefix, ampersands)
   - Parenthetical stripping (Remastered, Live, Part numbers)
   - Confidence scoring requiring BOTH artist and title matches
   - AI retry logic when no good match found
   - MusicMatchingProtocol for future LLM-based matching

9. **AI Model Configuration** ✅
   - ConfigurationView for model and reasoning level settings
   - AIModelConfig with UserDefaults persistence
   - Separate configs for song selection vs style guide generation
   - Model options: GPT-5, GPT-5 Mini, GPT-5 Nano
   - Reasoning levels: low, medium, high

### Not Yet Implemented
- Playlist export to Apple Music
- Crossfade/BPM-aware transitions
- Spotify integration
- Multi-user support
- Voice interaction

## Project Structure
```
Back2Back/
├── Back2Back/                    # Main app target
│   ├── Back2BackApp.swift       # App entry point with B2BLog initialization
│   ├── ContentView.swift        # Main tab navigation (Session, Personas, Config)
│   ├── SecretsTemplate.swift    # Template for API keys configuration
│   ├── Models/
│   │   ├── MusicModels.swift           # MusicSearchResult, NowPlayingItem, error types
│   │   ├── PersonaModels.swift         # Persona and PersonaGenerationResult
│   │   ├── PersonaSongCache.swift      # CachedSong, PersonaSongCache (24hr expiration)
│   │   ├── AIModelConfig.swift         # AI model configuration and persistence
│   │   ├── OpenAIModels.swift          # Core OpenAI API types
│   │   ├── OpenAIModels+Core.swift     # Base request/response types
│   │   ├── OpenAIModels+Components.swift  # Message, ToolCall, etc.
│   │   └── OpenAIModels+Streaming.swift   # Streaming response types
│   ├── Views/
│   │   ├── MusicAuthorizationView.swift  # Apple Music permission UI
│   │   ├── MusicSearchView.swift         # Search UI with debounced input
│   │   ├── NowPlayingView.swift          # Mini/expanded player views
│   │   ├── SessionView.swift             # DJ session UI with history/queue
│   │   ├── PersonasListView.swift        # Persona management list
│   │   ├── PersonaDetailView.swift       # Edit/create persona
│   │   └── ConfigurationView.swift       # AI model settings and debug tools
│   ├── Services/
│   │   ├── MusicService.swift            # Singleton MusicKit wrapper (@MainActor)
│   │   ├── SessionService.swift          # Session state management
│   │   ├── PersonaService.swift          # Persona CRUD operations
│   │   ├── PersonaSongCacheService.swift # 24hr song repetition prevention
│   │   ├── EnvironmentService.swift      # Secure API key management
│   │   ├── OpenAIClient.swift            # Core OpenAI HTTP client
│   │   ├── OpenAIClient+Responses.swift  # Responses API implementation
│   │   ├── OpenAIClient+Streaming.swift  # Streaming response handling
│   │   ├── OpenAIClient+StreamHelpers.swift # Stream parsing utilities
│   │   ├── OpenAIClient+SongSelection.swift # Song recommendation logic
│   │   ├── OpenAIClient+Persona.swift    # Persona generation logic
│   │   └── MusicMatching/
│   │       ├── MusicMatchingProtocol.swift      # Matcher interface
│   │       ├── StringBasedMusicMatcher.swift    # Fuzzy string matching
│   │       └── LLMBasedMusicMatcher.swift       # Future LLM matcher (stub)
│   ├── ViewModels/
│   │   ├── MusicAuthViewModel.swift      # Auth state management
│   │   ├── MusicSearchViewModel.swift    # Search with 0.75s debouncing
│   │   ├── SessionViewModel.swift        # DJ session logic and AI coordination
│   │   ├── NowPlayingViewModel.swift     # Playback state management
│   │   ├── PersonasViewModel.swift       # Persona list management
│   │   └── PersonaDetailViewModel.swift  # Persona editing/creation
│   ├── Utils/
│   │   └── Logger.swift         # B2BLog unified logging system
│   └── Info.plist              # Background audio configuration
├── docs/
│   ├── back2back_requirements.md          # Original spec (DO NOT MODIFY)
│   └── openai-responses-api-web-search-swift.md  # OpenAI API documentation
└── Back2BackTests/              # Swift Testing framework tests
    ├── Back2BackTests.swift
    ├── MusicAuthViewModelTests.swift
    ├── MusicSearchViewModelTests.swift
    ├── MusicServiceTests.swift
    ├── MusicModelsTests.swift
    ├── SessionViewModelTests.swift         # Session logic, track matching tests
    ├── SessionServiceTests.swift
    ├── PersonaServiceTests.swift
    ├── PersonasViewModelTests.swift
    ├── PersonaSongCacheServiceTests.swift  # 24hr cache tests
    ├── OpenAIClientTests.swift
    ├── OpenAIModelsTests.swift
    ├── OpenAISongSelectionTests.swift
    ├── EnvironmentServiceTests.swift
    └── AIModelConfigTests.swift
```

## Development Guidelines

### MusicKit Setup (Xcode 13+ Changes)
**IMPORTANT**: Starting from Xcode 13 (and continuing in Xcode 26):
- Info.plist is now integrated into the project settings as "Custom iOS Target Properties"
- Access via: Project → Target → Info tab
- NSAppleMusicUsageDescription should be set via INFOPLIST_KEY_NSAppleMusicUsageDescription in build settings
- MusicKit is configured as an App Service (not an entitlement) in the Apple Developer portal

#### Required Configuration:
1. **Apple Developer Portal**:
   - Enable MusicKit in App Services for your App ID (com.saygoodnight.Back2Back)
   - This enables automatic developer token generation

2. **Xcode Project Settings**:
   - NSAppleMusicUsageDescription is already configured in project.pbxproj
   - Background audio mode is enabled in Info.plist

3. **Testing Requirements**:
   - MusicKit API calls require testing on a physical device (not simulator)
   - User must have accepted Apple Music privacy policy in the Music app
   - Device must have valid Apple Music subscription for full functionality

### Known Issues & Solutions

#### "Failed to request developer token" Error
This error occurs when automatic token generation fails. Common causes:
1. MusicKit not enabled in App Services (Developer Portal)
2. Bundle ID mismatch between Xcode and Developer Portal
3. Testing in simulator instead of physical device
4. User hasn't accepted Apple Music privacy policy
5. Provisioning profile needs refresh after enabling MusicKit

### API Keys Management
- Store OpenAI API keys securely (use Keychain or environment variables)
- Never commit API keys to the repository
- Use configuration files that are gitignored for local development

### Testing Approach
- **IMPORTANT**: Always use Swift Testing framework, never use XCTest
- Focus on fast-running unit tests only (no UI tests)
- Test with actual Apple Music subscription for full functionality
- Mock OpenAI responses for unit testing
- Test persona switching and turn management logic thoroughly

### UI/UX Principles
- Keep interface simple and focused on the current turn
- Provide clear visual feedback when AI is "thinking"
- Show brief rationale for AI song choices
- Smooth transitions between songs

## Future Enhancements
- Spotify integration
- Crossfade/BPM-aware transitions
- Export session as Apple Music playlist
- Multi-user support
- Voice interaction

## Legal Considerations
- Personas are "inspired by" public figures, not impersonations
- Include clear disclaimers in the app
- Respect Apple Music licensing requirements
- Handle user privacy appropriately (don't store unnecessary listening data)

## Build & Run Commands
```bash
# Build the project
xcodebuild -project Back2Back.xcodeproj -scheme Back2Back -configuration Debug build

# Run unit tests (Swift Testing framework)
xcodebuild test -project Back2Back.xcodeproj -scheme Back2Back -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# Clean build folder
xcodebuild clean -project Back2Back.xcodeproj -scheme Back2Back
```

## Recent Improvements (September 2025)

### Time-Based Song Repetition Prevention (PR #19)
Implemented a 24-hour cache system to prevent personas from selecting the same songs across different sessions:
- **PersonaSongCache models**: CachedSong and PersonaSongCache with automatic expiration
- **PersonaSongCacheService**: Singleton with UserDefaults persistence
- **Integration**: AI prompts now include exclusion list of recent songs
- **Debug tools**: Clear cache button in ConfigurationView

### Tap-to-Skip Functionality
Allow users to tap any queued song to skip ahead:
- **SessionSongRow**: Tap gesture on queued items
- **SessionViewModel.skipToQueuedSong()**: Handles skip logic
- **SessionService.removeQueuedSongsBeforeSong()**: Queue management helper

### Improved Track Matching (PR #17)
Enhanced verification between AI recommendations and Apple Music search:
- **Unicode normalization**: Handles curly quotes (U+2019), diacritics
- **Artist/title normalization**: Featuring artists, "The" prefix, ampersands, abbreviations
- **Parenthetical stripping**: Removes "(Remastered)", "(Live)", "Pt. 1", etc.
- **Stricter matching**: Requires BOTH artist AND title partial matches (prevents wrong song selection)
- **AI retry logic**: When no good match found, AI selects alternative song
- **Music matching architecture**: Extracted to MusicMatching/ module with protocol-based design

### Queue Readiness Improvements
- **prepareToPlay()**: Ensures queue is ready before playback starts
- Prevents playback errors from uninitialized queue state

### Product Naming
- App renamed to "Back2Back DJ" in App Store/Home Screen
- Internal module name remains "Back2Back" for consistency

## Implementation Details

### Logging System (B2BLog)
The app uses a comprehensive logging system with OSLog:
- **Subsystems**: musicKit, auth, search, playback, ui, network, ai, session, general
- **Log Levels**: trace, debug, info, notice, warning, error
- **Special Methods**:
  - `performance(metric, value)` for performance metrics
  - `userAction(action)` for user interactions
  - `stateChange(from, to)` for state transitions
  - `apiCall(endpoint)` for network requests
  - `success(message)` for successful operations

### Performance Optimizations
- **Search Debouncing**: 0.75s delay using Combine's debounce operator
- **Non-blocking UI**: Heavy operations run on background queues with Task.detached
- **Lazy Loading**: LazyVStack for search results
- **Async Image Loading**: Properly sized artwork requests (60x60 for list items)

### Architecture Patterns
- **MVVM**: Clear separation between Views and ViewModels
- **@Observable**: Modern observation framework (iOS 17+, enhanced in iOS 26)
- **Singleton Pattern**: MusicService.shared for centralized state
- **Swift Concurrency**: async/await throughout, no completion handlers
- **@MainActor**: Ensures UI updates on main thread

### Current Test Coverage
- Authorization flow (MusicAuthViewModelTests)
- Search functionality (MusicSearchViewModelTests)
- Service layer (MusicServiceTests, SessionServiceTests, PersonaServiceTests)
- Model validation (MusicModelsTests, OpenAIModelsTests)
- OpenAI integration (OpenAIClientTests, OpenAISongSelectionTests)
- Session logic and track matching (SessionViewModelTests)
  - String normalization (Unicode, diacritics, "The" prefix, ampersands)
  - Parenthetical stripping (Remastered, Live, Part numbers)
  - Confidence scoring and threshold logic
  - Featuring artist variations
- Persona management (PersonasViewModelTests)
- Song cache system (PersonaSongCacheServiceTests)
  - 24-hour expiration logic
  - Multi-persona isolation
  - Cache persistence and cleanup
- Environment configuration (EnvironmentServiceTests)
- AI model configuration (AIModelConfigTests)

## Important Notes
- Always test with real Apple Music subscription
- MusicKit requires physical device (simulator won't work)
- Ensure AI response times don't interrupt music flow (when implemented)
- Keep persona suggestions tasteful and appropriate (future feature)
- Follow Apple's Human Interface Guidelines for iOS apps
- Use B2BLog for all logging - no print statements
- Maintain non-blocking UI with proper concurrency patterns