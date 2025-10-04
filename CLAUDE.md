# Back2Back (B2B) Project Context

## Current Environment (IMPORTANT)
**Current Date**: 2025
**iOS Version**: iOS 26 (latest)
**Xcode Version**: Xcode 26 (latest)

⚠️ **Note for web searches**: We are in 2025 using iOS 26 and Xcode 26. When searching for documentation or solutions, prioritize recent content from 2025 and iOS 26/Xcode 26 specific resources.

## Project Overview
Back2Back is an iOS app that creates an interactive DJ experience where users and AI take turns selecting songs, creating a collaborative back-to-back DJ session. The AI selects tracks based on configurable personas (e.g., "Mark Ronson," "1970s NYC crate digger").

## Requirements Document
Primary requirements are documented in: `internal_docs/back2back_requirements.md`

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
- **Documentation**: The OpenAI Responses API documentation is available at `internal_docs/openai-responses-api-web-search-swift.md`
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
   - Automatic queue management: songs queued to MusicKit at 95% progress
   - Now Playing UI (mini and expanded views) with interactive controls
   - Live playback progress tracking
   - Interactive scrubbing and seek controls
   - Skip forward/backward (±15s) functionality
   - Tap-to-skip functionality for queued songs

3. **Turn-based song selection (user → AI → user)** ✅
   - Automatic turn management in SessionService and TurnManager
   - User can select songs via search
   - AI automatically queues next song using current persona
   - Visual feedback showing current turn (User/AI)
   - Smart queue status logic:
     - `.upNext` when it's AI's turn (AI's active pick, turn switches after)
     - `.queuedIfUserSkips` when it's user's turn (AI backup, turn stays on user)
   - Automatic transitions via MusicKit queue progression

4. **Persona library with preset and custom options** ✅
   - PersonaService with UserDefaults persistence
   - Default personas: "Rare Groove Collector", "Modern Electronic DJ"
   - Create, edit, delete, and select personas
   - AI-powered style guide generation with streaming progress
   - Generation time warnings for user expectations (can take several minutes)
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

10. **Playback Controls & Progress** ✅
   - Interactive progress bar with tap-to-seek and drag support
   - Live playback time tracking (500ms polling)
   - Skip forward/backward buttons (±15s jumps)
   - Visual feedback during scrubbing
   - Increased hit areas for better touch targets

11. **Dynamic Direction Change Button** ✅
   - AI-generated contextual direction suggestions during user's turn
   - Analyzes session history to suggest contrasting musical directions
   - Smart button label generation (e.g., "West Coast vibes", "60s garage rock")
   - Automatically regenerates when new songs play
   - Task ID-based cancellation prevents race conditions
   - GPT-5-mini powered for fast, cost-effective suggestions
   - Turn remains on user after direction change (AI provides backup)

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
│   │   ├── DirectionChange.swift       # Direction change prompt and button label
│   │   ├── AIModelConfig.swift         # AI model configuration and persistence
│   │   ├── OpenAIModels.swift          # Core OpenAI API types
│   │   ├── OpenAIModels+Core.swift     # Base request/response types
│   │   ├── OpenAIModels+Components.swift  # Message, ToolCall, etc.
│   │   └── OpenAIModels+Streaming.swift   # Streaming response types
│   ├── Coordinators/           # (NEW) Coordination layer for complex workflows
│   │   ├── PlaybackCoordinator.swift     # Playback monitoring and transitions
│   │   ├── TurnManager.swift             # Turn state and queue advancement logic
│   │   └── AISongCoordinator.swift       # AI song selection coordination
│   ├── Protocols/              # (NEW) Abstraction protocols
│   │   ├── MusicServiceProtocol.swift           # Music service interface
│   │   ├── AIRecommendationServiceProtocol.swift # AI recommendation interface
│   │   └── SessionStateManagerProtocol.swift     # Session state interface
│   ├── Views/
│   │   ├── MusicAuthorizationView.swift  # Apple Music permission UI
│   │   ├── MusicSearchView.swift         # Search UI with debounced input
│   │   ├── NowPlayingView.swift          # Mini/expanded player with interactive controls
│   │   ├── SessionView.swift             # DJ session UI with history/queue
│   │   ├── PersonasListView.swift        # Persona management list
│   │   ├── PersonaDetailView.swift       # Edit/create persona
│   │   ├── ConfigurationView.swift       # AI model settings and debug tools
│   │   ├── Session/              # Session-specific subviews
│   │   │   ├── SessionHeaderView.swift
│   │   │   ├── SessionHistoryListView.swift
│   │   │   ├── SessionSongRow.swift
│   │   │   ├── SessionActionButtons.swift
│   │   │   └── AILoadingCell.swift
│   │   └── Personas/             # Persona-specific subviews
│   │       ├── GenerationProgressView.swift
│   │       ├── KeyboardToolbarGenerateButton.swift
│   │       └── SourcesListView.swift
│   ├── Services/
│   │   ├── MusicService.swift            # Facade pattern MusicKit wrapper (@MainActor)
│   │   ├── SessionService.swift          # Session state coordination
│   │   ├── PersonaService.swift          # Persona CRUD operations
│   │   ├── PersonaSongCacheService.swift # 24hr song repetition prevention
│   │   ├── EnvironmentService.swift      # Secure API key management
│   │   ├── MusicKit/             # (NEW) MusicKit service layer
│   │   │   ├── MusicAuthService.swift    # Authorization handling
│   │   │   ├── MusicSearchService.swift  # Catalog search with pagination
│   │   │   └── MusicPlaybackService.swift # Playback, seek, skip controls
│   │   ├── Session/              # (NEW) Session management services
│   │   │   ├── QueueManager.swift        # Queue operations
│   │   │   └── SessionHistoryService.swift # History tracking
│   │   ├── OpenAI/               # (NEW) OpenAI service layer
│   │   │   ├── Core/
│   │   │   │   ├── OpenAIClient.swift    # HTTP client
│   │   │   │   └── OpenAIConfig.swift    # Configuration
│   │   │   ├── Features/
│   │   │   │   ├── SongSelectionService.swift    # Song recommendations & direction changes
│   │   │   │   └── PersonaGenerationService.swift # Persona generation
│   │   │   └── Networking/
│   │   │       ├── OpenAINetworking.swift # Network layer
│   │   │       └── OpenAIStreaming.swift  # Streaming responses
│   │   └── MusicMatching/
│   │       ├── MusicMatchingProtocol.swift      # Matcher interface
│   │       ├── StringBasedMusicMatcher.swift    # Fuzzy string matching
│   │       └── LLMBasedMusicMatcher.swift       # Future LLM matcher (stub)
│   ├── ViewModels/
│   │   ├── MusicAuthViewModel.swift      # Auth state management
│   │   ├── MusicSearchViewModel.swift    # Search with 0.75s debouncing
│   │   ├── SessionViewModel.swift        # DJ session logic, AI coordination, direction changes
│   │   ├── NowPlayingViewModel.swift     # Playback state with live tracking
│   │   ├── PersonasViewModel.swift       # Persona list management
│   │   ├── PersonaDetailViewModel.swift  # Persona editing/creation
│   │   └── ViewModelError.swift          # (NEW) Unified error handling protocol
│   ├── Utils/
│   │   ├── Logger.swift          # B2BLog unified logging system
│   │   └── AIRetryStrategy.swift # (NEW) Generic AI retry logic
│   └── Info.plist               # Background audio configuration
├── internal_docs/
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

## Recent Improvements (September-October 2025)

### Dynamic Direction Change Button (PR #38, October 2025)
Intelligent AI-powered session steering feature:
- **AI-Generated Suggestions**: GPT-5-mini analyzes session history to suggest contrasting musical directions
- **Smart Prompts**: Identifies dominant patterns (regions, eras, tempos, genres) and suggests dramatic contrasts
- **Dynamic Button Labels**: Context-aware labels like "West Coast vibes", "60s garage rock", "Downtempo shift"
- **Automatic Regeneration**: Button updates when new songs play and when tapped
- **Turn Logic**: Direction changes queue AI backup song while keeping turn on user
- **Task ID-Based Cancellation**: Prevents race conditions when tapping during AI thinking
- **DirectionChange Model**: Contains both detailed prompt for AI and short button label for UI
- **Bug Fixes**:
  - Fixed cancellation state bleeding between old and new tasks (b220ef5)
  - Added Task.isCancelled checks to stop retry loops (d79c19f)
  - Explicit AI thinking state reset to prevent race conditions (0f4af4a)
  - Active regeneration when songs play during user's turn (d8ca5f7)

### Simplified Queue Management (PR #36, October 2025)
Complete overhaul of queue management for smoother playback:
- **95% Queueing Strategy**: Songs queued to MusicKit at 95% progress instead of manual stop at 97%
- **Natural Transitions**: MusicKit handles fade-outs and song transitions automatically
- **Fixed Turn Logic**: TurnManager correctly uses `currentTurn` state
- **Queue Status Intelligence**:
  - `.upNext` when AI's turn → plays automatically, turn switches after
  - `.queuedIfUserSkips` when user's turn → AI backup, turn stays on user
- **PlaybackCoordinator**: Monitors at 95%, queues next song, fallback at 99%
- **Benefits**: Songs play to completion, smoother transitions, simpler code

### Interactive Playback Controls (PR #27, September 2025)
Comprehensive playback control implementation:
- **Live Progress Tracking**: 500ms polling for real-time playback position
- **Interactive Scrubbing**: Tap-to-seek and drag gesture support
- **Skip Controls**: ±15s forward/backward buttons
- **Enhanced UI**: Larger hit areas, visual feedback during scrubbing
- **NowPlayingViewModel**: Manages playback timer lifecycle and state

### Architecture Refactoring (PRs #23, #25, September 2025)
Major code organization improvements:
- **Coordinators Layer**: PlaybackCoordinator, TurnManager, AISongCoordinator
- **Service Split**: MusicKit (Auth/Search/Playback), Session (Queue/History), OpenAI (Core/Features/Networking)
- **Protocol Abstractions**: MusicServiceProtocol, AIRecommendationServiceProtocol, SessionStateManagerProtocol
- **Unified Error Handling**: ViewModelError protocol with B2BLog integration
- **AI Retry Strategy**: Generic retry logic extracted to Utils/AIRetryStrategy.swift
- **Code Metrics**: Reduced from 8 files >300 lines to 0, improved separation of concerns

### Persona Generation UX (October 2025)
Enhanced user experience for AI-powered persona creation:
- **Time Warnings**: Clear messaging that generation may take several minutes
- **Progress Indicators**: Visual feedback with status-specific icons
- **Streaming Updates**: Real-time progress from OpenAI API
- **Better Expectations**: Users understand the advanced AI processing time

### Time-Based Song Repetition Prevention (PR #19, September 2025)
Implemented a 24-hour cache system to prevent personas from selecting the same songs across different sessions:
- **PersonaSongCache models**: CachedSong and PersonaSongCache with automatic expiration
- **PersonaSongCacheService**: Singleton with UserDefaults persistence
- **Integration**: AI prompts now include exclusion list of recent songs
- **Debug tools**: Clear cache button in ConfigurationView

### Improved Track Matching (PR #17, September 2025)
Enhanced verification between AI recommendations and Apple Music search:
- **Unicode normalization**: Handles curly quotes (U+2019), diacritics
- **Artist/title normalization**: Featuring artists, "The" prefix, ampersands, abbreviations
- **Parenthetical stripping**: Removes "(Remastered)", "(Live)", "Pt. 1", etc.
- **Stricter matching**: Requires BOTH artist AND title partial matches (prevents wrong song selection)
- **AI retry logic**: When no good match found, AI selects alternative song
- **Music matching architecture**: Extracted to MusicMatching/ module with protocol-based design

### Additional Enhancements
- **Tap-to-Skip Functionality**: Users can tap any queued song to skip ahead
- **Pagination Support**: MusicKit catalog search now supports pagination for better results
- **AI Song Variety**: Enhanced prompts to avoid repetition and prioritize surprises
- **Retry Resilience**: Increased retry attempts from 2 to 10 for better song matching
- **Product Naming**: App renamed to "Back2Back DJ" in App Store/Home Screen

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

### Queue Management System
The app uses a sophisticated queue management system that leverages MusicKit's native queue progression:

1. **95% Queueing Strategy**:
   - PlaybackCoordinator monitors playback progress every 0.5s
   - At 95% progress, next song is queued to MusicKit using `queue.insert(song, position: .tail)`
   - MusicKit handles natural transitions with fade-outs
   - Fallback to manual transition at 99% if queueing fails

2. **Turn-Based Queue Status**:
   - **When User's Turn**: AI queues as `.queuedIfUserSkips` (backup only)
     - If user selects a song, AI backup is removed from queue
     - If user doesn't select, AI backup plays and turn STAYS on user
   - **When AI's Turn**: AI queues as `.upNext` (active pick)
     - Song will definitely play next
     - After playing, turn switches to user

3. **Automatic State Management**:
   - State observer detects song changes via MusicKit publisher
   - `SessionService.updateCurrentlyPlayingSong()` moves songs from queue to history
   - Turn switching logic based on queue status (not just selectedBy)
   - `TurnManager.determineNextQueueStatus()` decides queue status based on `currentTurn`

4. **Benefits**:
   - Songs play to full completion (no 97% cutoff)
   - Smooth MusicKit-managed transitions
   - Correct turn logic prevents UI button confusion
   - Simpler codebase using native queue progression

### Direction Change System
The app provides intelligent musical direction steering during user turns:

1. **AI-Powered Direction Generation**:
   - Uses GPT-5-mini for fast, cost-effective suggestions
   - `SongSelectionService.generateDirectionChange()` analyzes session history
   - Identifies dominant patterns: regions, eras, tempos, genres, moods, production styles
   - Suggests DRAMATIC CONTRASTS rather than minor variations
   - Example: If session has many New Orleans tracks → suggests "West Coast psychedelic" not "Southern soul"

2. **DirectionChange Model**:
   - `directionPrompt`: Detailed guidance for AI song selection (1-2 sentences)
   - `buttonLabel`: User-facing text for UI button (2-4 words max)
   - Example: `{directionPrompt: "Focus on West Coast psychedelic rock with experimental production", buttonLabel: "West Coast vibes"}`

3. **Automatic Regeneration Triggers**:
   - When direction button first appears (`.task` modifier in SessionActionButtons)
   - When user taps direction button (`clearDirectionCache()` + `generateDirectionChange()`)
   - When new song starts playing during user's turn (`playCurrentSong()` checks turn state)
   - Caching prevents redundant generation for same song

4. **Task Management for Race Condition Prevention**:
   - **Task ID System**: Each prefetch gets unique UUID, checked throughout operation
   - **Superseding Not Cancelling**: New tasks invalidate old task IDs without calling `.cancel()`
   - **Prevents Cancellation Bleeding**: Task.isCancelled doesn't affect new tasks
   - **Multiple Checkpoints**: Task ID validated before/after AI selection, search, queueing
   - **Retry Loop Protection**: `AIRetryStrategy` checks `Task.isCancelled` before retries
   - **Explicit State Reset**: `sessionService.setAIThinking(false)` before starting new task

5. **User Interaction Flow**:
   - User's turn → direction button appears with suggestion
   - User taps button → cancels existing AI task, clears queue, starts new prefetch with direction
   - New AI selection uses `directionPrompt` appended to persona prompt
   - Song queued as `.queuedIfUserSkips` (turn stays on user, not switched)
   - Direction cache cleared immediately, fresh suggestion generated for next tap

6. **Turn Logic Integration**:
   - Direction changes treated as AI suggestions, not user selections
   - Turn remains `.user` after direction change
   - User can tap direction multiple times or select their own song
   - AI backup removed if user selects manually

### Architecture Patterns
- **MVVM + Coordinators**: Clear separation with coordination layer for complex workflows
- **@Observable**: Modern observation framework (iOS 17+, enhanced in iOS 26)
- **Facade Pattern**: MusicService.shared delegates to specialized sub-services
- **Protocol-Oriented**: Abstractions for testability and flexibility
- **Single Responsibility**: Services split by concern (Auth, Search, Playback, Queue, History)
- **Swift Concurrency**: async/await throughout, no completion handlers
- **@MainActor**: Ensures UI updates on main thread
- **Task ID-Based Coordination**: Prevents race conditions in async workflows

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