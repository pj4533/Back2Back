# Back2Back (B2B)

An interactive iOS DJ experience where users and AI take turns selecting songs, creating a collaborative back-to-back DJ session.

## Overview

Back2Back transforms music listening into a collaborative DJ experience. Users play songs, and an AI DJ responds with complementary tracks based on customizable personas (like "Mark Ronson" or "1970s NYC crate digger"). It's not just a playlist generator—it's your AI co-DJ partner.

## Current Implementation Status

### Fully Implemented Features ✅

#### Apple Music Integration
- Full MusicKit authorization flow with proper error handling
- Real-time catalog search with performance-optimized debouncing (0.75s)
- Music playback via ApplicationMusicPlayer with automatic queue management
- Intelligent 95% queueing strategy for smooth song transitions
- Now Playing view with mini/expanded player UI and interactive controls
- Live playback progress tracking with scrubbing support
- Skip forward/backward controls (±15s jumps)
- Tap-to-skip functionality for queued songs

#### AI-Powered DJ Experience
- **OpenAI Integration**: GPT-5 Responses API for intelligent song selection
- **Persona System**: Create, edit, and manage custom DJ personas
  - Default personas: "Rare Groove Collector", "Modern Electronic DJ"
  - AI-powered style guide generation with streaming progress
  - Generation time warnings for proper user expectations
  - Persistent storage via UserDefaults
- **Turn-based Logic**: Automatic alternation between user and AI selections
  - Smart queue status: `.upNext` (AI's turn) vs `.queuedIfUserSkips` (user's turn)
  - Turn switching based on queue status for correct behavior
- **Intelligent Prefetching**: AI pre-selects next song while current song plays
- **AI Model Configuration**: Choose between GPT-5, GPT-5 Mini, GPT-5 Nano with adjustable reasoning levels
- **Dynamic Direction Change**: AI-generated contextual suggestions to steer the session
  - Analyzes session history to identify dominant patterns
  - Suggests dramatic contrasts (different eras, regions, tempos, moods)
  - Smart button labels like "West Coast vibes", "60s garage rock"
  - Automatically regenerates as session evolves
  - Proper task cancellation prevents race conditions (PR #78)
- **AI Starts Button**: Pre-caches first song for instant playback (PR #82)
  - Background pre-fetching eliminates wait time
  - Dedicated FirstSelectionCache logging for debugging
  - Seamless session start experience
- **Dynamic Status Messages**: Persona-specific AI thinking messages
  - Generated using Apple FoundationModels framework
  - Genre-specific messages (e.g., "Digging through crates..." for hip-hop)
  - Cached with usage-based regeneration (every 3 uses)
  - Non-blocking fire-and-forget generation pattern
- **Favorites System**: Save and manage favorite songs
  - Heart icon in session history to favorite songs
  - Dedicated Favorites tab with swipe-to-delete
  - Tracks persona association with each favorite
  - UserDefaults persistence

#### Advanced Song Matching
- **StringBasedMusicMatcher**: Fuzzy matching with sophisticated normalization
  - Unicode normalization (curly quotes, diacritics)
  - Artist variations (featuring artists, "The" prefix, ampersands, abbreviations)
  - Title cleaning (parentheticals, part numbers, remaster tags)
  - Confidence scoring requiring BOTH artist AND title matches
- **LLMBasedMusicMatcher**: Apple FoundationModels-powered matching (PR #42, #47)
  - AI-based track matching for difficult cases
  - Foundation Model validation to verify persona alignment (PR #48, #49)
- **AI Retry Logic**: Automatic retry when no good match is found
- **Protocol-based Architecture**: MusicMatchingProtocol for swappable strategies

#### Session Management
- **Full Session History**: Track all played and queued songs
- **Queue Status Tracking**: playing, played, upNext, queuedIfUserSkips
- **Turn Visualization**: Clear indication of whose turn (User/AI)
- **Session Persistence**: Maintains state throughout app lifecycle

#### Count-Based LRU Song Repetition Prevention
- **LRU Cache**: Prevents personas from repeating their most recent N songs (default: 50)
- **Configurable Cache Size**: User can adjust from 10-500 songs in settings
- **Per-Persona Tracking**: Each persona has independent cache
- **Automatic Eviction**: Oldest songs automatically removed when limit reached
- **Persona Song Cache UI**: View and manage cached songs per persona (PR #83)
- **Debug Tools**: Clear cache button and cache viewer in configuration

#### Core Infrastructure
- Comprehensive logging system using OSLog with 10 subsystem categories (including FirstSelectionCache)
- Swift 6+ concurrency with async/await patterns throughout
- Non-blocking UI updates using Swift Concurrency
- Clean MVVM architecture with complete View/ViewModel separation (PR #75)
- ServiceContainer with environment-based dependency injection
- Protocol-oriented design for testability and flexibility
- Facade pattern for service layer organization
- Secure API key management via EnvironmentService
- 258 passing unit tests (100% success rate) with comprehensive mocks (PR #77)

#### User Interface
- Tab-based navigation: Session, Favorites, Personas, Configuration
- Clean SwiftUI-based interface with smooth animations
- Authorization view with Settings deep-linking
- Real-time search with debounced results
- Now Playing mini-player and expanded view
- Session view with history and queue display
- Favorites list with swipe-to-delete and heart icon
- Persona management with create/edit/delete
- Configuration UI for AI model settings and cache management
- Song Errors view for debugging failed AI selections (PR #51)

### Planned Future Features
- **Playlist Export** - Save sessions as Apple Music playlists
- **Advanced Transitions** - Crossfade and BPM-aware mixing
- **Spotify Integration** - Support for Spotify playback
- **Multi-user Support** - Collaborative sessions
- **Voice Interaction** - Voice commands for control

## Requirements

- **iOS Version**: iOS 17.0+ (required for latest MusicKit features)
- **Xcode**: 16.0+ (for Swift 6 support)
- **Apple Music**: Active subscription required for full functionality
- **OpenAI API Key**: Required for AI song selection and persona features
- **Device**: Physical iOS device (MusicKit doesn't work in simulator)
- **Developer Account**: Apple Developer account with MusicKit service enabled

## Installation

### 1. Clone the Repository
```bash
git clone https://github.com/yourusername/Back2Back.git
cd Back2Back
```

### 2. Configure API Keys

1. **Create Secrets.swift file**:
   ```bash
   # Copy the template
   cp Back2Back/SecretsTemplate.swift Back2Back/Secrets.swift
   ```

2. **Add your OpenAI API key**:
   - Open `Back2Back/Secrets.swift`
   - Replace `"your-openai-api-key-here"` with your actual OpenAI API key
   - Note: `Secrets.swift` is gitignored and won't be committed

### 3. Apple Developer Configuration

1. **Enable MusicKit in Apple Developer Portal**:
   - Sign in to [Apple Developer Portal](https://developer.apple.com)
   - Navigate to Certificates, Identifiers & Profiles
   - Select your App ID (com.saygoodnight.Back2Back)
   - Enable "MusicKit" under App Services (NOT Capabilities)
   - Save changes

2. **Configure Xcode Project**:
   - Open `Back2Back.xcodeproj` in Xcode
   - Select the project in navigator
   - Under "Signing & Capabilities":
     - Set your Team
     - Verify Bundle Identifier matches your App ID
   - Build Settings are already configured with:
     - `INFOPLIST_KEY_NSAppleMusicUsageDescription`
     - Background audio capability in Info.plist

### 4. Build and Run

```bash
# Build the project
xcodebuild -project Back2Back.xcodeproj -scheme Back2Back -configuration Debug build

# Or simply open in Xcode and press Cmd+R
```

**Important**: You must run on a physical device with:
- An active Apple Music subscription
- Apple Music app installed and privacy policy accepted
- iOS 17.0 or later

## Project Structure

```
Back2Back/
├── Back2Back/                  # Main app target
│   ├── Back2BackApp.swift     # App entry point with logging initialization
│   ├── ContentView.swift      # Main tab navigation (Session, Personas, Config)
│   ├── SecretsTemplate.swift  # Template for API keys (copy to Secrets.swift)
│   ├── Models/
│   │   ├── MusicModels.swift           # Music search and playback models
│   │   ├── PersonaModels.swift         # Persona and generation result types
│   │   ├── PersonaSongCache.swift      # 24-hour song cache models
│   │   ├── DirectionChange.swift       # Direction change prompt and button label
│   │   ├── AIModelConfig.swift         # AI configuration and persistence
│   │   ├── OpenAIModels.swift          # OpenAI API types
│   │   ├── OpenAIModels+Core.swift     # Base request/response types
│   │   ├── OpenAIModels+Components.swift  # Message, ToolCall, etc.
│   │   └── OpenAIModels+Streaming.swift   # Streaming response types
│   ├── Coordinators/          # Coordination layer for complex workflows
│   │   ├── PlaybackCoordinator.swift   # 95% queueing & transitions
│   │   ├── TurnManager.swift           # Turn logic & queue advancement
│   │   └── AISongCoordinator.swift     # AI song selection workflow
│   ├── Protocols/             # Protocol abstractions for testability
│   │   ├── MusicServiceProtocol.swift
│   │   ├── AIRecommendationServiceProtocol.swift
│   │   └── SessionStateManagerProtocol.swift
│   ├── Services/
│   │   ├── MusicService.swift            # Facade pattern wrapper
│   │   ├── SessionService.swift          # Session coordination
│   │   ├── PersonaService.swift          # Persona CRUD operations
│   │   ├── PersonaSongCacheService.swift # 24hr repetition prevention
│   │   ├── EnvironmentService.swift      # Secure API key management
│   │   ├── MusicKit/          # MusicKit service layer
│   │   │   ├── MusicAuthService.swift    # Authorization
│   │   │   ├── MusicSearchService.swift  # Catalog search
│   │   │   └── MusicPlaybackService.swift # Playback controls
│   │   ├── Session/           # Session management
│   │   │   ├── QueueManager.swift
│   │   │   └── SessionHistoryService.swift
│   │   ├── OpenAI/            # OpenAI service layer
│   │   │   ├── Core/
│   │   │   │   ├── OpenAIClient.swift
│   │   │   │   └── OpenAIConfig.swift
│   │   │   ├── Features/
│   │   │   │   ├── SongSelectionService.swift    # Song selection & direction changes
│   │   │   │   └── PersonaGenerationService.swift
│   │   │   └── Networking/
│   │   │       ├── OpenAINetworking.swift
│   │   │       └── OpenAIStreaming.swift
│   │   └── MusicMatching/
│   │       ├── MusicMatchingProtocol.swift
│   │       ├── StringBasedMusicMatcher.swift
│   │       └── LLMBasedMusicMatcher.swift
│   ├── ViewModels/
│   │   ├── MusicAuthViewModel.swift      # Authorization state
│   │   ├── MusicSearchViewModel.swift    # Search with debouncing
│   │   ├── SessionViewModel.swift        # DJ session logic & direction changes
│   │   ├── NowPlayingViewModel.swift     # Playback with live tracking
│   │   ├── PersonasViewModel.swift       # Persona list management
│   │   ├── PersonaDetailViewModel.swift  # Persona editing
│   │   └── ViewModelError.swift          # Unified error handling
│   ├── Views/
│   │   ├── MusicAuthorizationView.swift  # Authorization UI
│   │   ├── MusicSearchView.swift         # Search interface
│   │   ├── NowPlayingView.swift          # Interactive playback controls
│   │   ├── SessionView.swift             # DJ session UI
│   │   ├── PersonasListView.swift        # Persona management
│   │   ├── PersonaDetailView.swift       # Edit/create persona
│   │   ├── ConfigurationView.swift       # AI settings and debug
│   │   ├── Session/           # Session subviews
│   │   │   ├── SessionHeaderView.swift
│   │   │   ├── SessionHistoryListView.swift
│   │   │   ├── SessionSongRow.swift
│   │   │   ├── SessionActionButtons.swift
│   │   │   └── AILoadingCell.swift
│   │   └── Personas/          # Persona subviews
│   │       ├── GenerationProgressView.swift
│   │       ├── KeyboardToolbarGenerateButton.swift
│   │       └── SourcesListView.swift
│   ├── Utils/
│   │   ├── Logger.swift       # OSLog-based logging (9 subsystems)
│   │   └── AIRetryStrategy.swift # Generic retry logic
│   └── Info.plist             # Background audio configuration
├── Back2BackTests/            # Swift Testing framework (20+ test files)
├── internal_docs/
│   ├── back2back_requirements.md          # Original specification
│   └── openai-responses-api-web-search-swift.md  # OpenAI API docs
├── CLAUDE.md                  # Development guidelines and context
└── README.md                  # This file
```

## Architecture

### Design Patterns
- **MVVM Architecture**: Clear separation between Views and ViewModels
- **Singleton Services**: `MusicService.shared` for centralized music control
- **Observable Pattern**: Using `@Observable` and `@StateObject` for reactive UI
- **Async/Await**: Modern concurrency for all asynchronous operations

### Key Components

#### Coordinators Layer (NEW)
**PlaybackCoordinator**: Monitors playback and manages transitions
- 95% queueing strategy for smooth transitions
- State observer for automatic song change detection
- Fallback logic at 99% if queueing fails

**TurnManager**: Manages turn state and queue advancement
- `determineNextQueueStatus()` - decides queue status based on current turn
- `advanceToNextSong()` - handles automatic song progression
- `skipToSong()` - handles user-initiated skips

**AISongCoordinator**: Orchestrates AI song selection workflow
- Coordinates between AI service, music matching, and session state
- Handles retry logic using AIRetryStrategy
- Manages prefetching for smooth playback

#### MusicService (Facade Pattern)
Central service delegating to specialized sub-services:
- **MusicAuthService**: Authorization handling with Settings deep-linking
- **MusicSearchService**: Catalog search with pagination support
- **MusicPlaybackService**: Playback control, seek, skip (±15s), real-time state
- Maintains backward compatibility while enabling single-responsibility services

#### SessionService
Coordinates session state across sub-services:
- **SessionHistoryService**: History tracking with metadata and status updates
- **QueueManager**: Queue operations (add, remove, get next)
- Turn management with queue status-based logic
- Integration point for PlaybackCoordinator and TurnManager

#### PersonaService
Handles DJ persona management:
- Create, read, update, delete personas
- Persistent storage via UserDefaults
- Default persona initialization
- Active persona tracking

#### PersonaSongCacheService
Time-based repetition prevention:
- 24-hour song cache per persona
- Automatic expiration on initialization
- UserDefaults persistence
- Recent song exclusion for AI prompts

#### OpenAI Services (Organized by Layer)
**Core Layer**:
- **OpenAIClient**: HTTP client with request/response handling
- **OpenAIConfig**: Configuration management

**Features Layer**:
- **SongSelectionService**: GPT-5-powered song recommendations with persona context
- **PersonaGenerationService**: Streaming persona style guide generation

**Networking Layer**:
- **OpenAINetworking**: Network request handling
- **OpenAIStreaming**: Streaming response parsing

#### StringBasedMusicMatcher
Intelligent track matching:
- Fuzzy string matching with normalization
- Unicode and diacritic handling
- Artist/title variation normalization
- Confidence scoring (requires both matches)
- Protocol-based for easy replacement

#### Logging System (B2BLog)
Comprehensive logging with 9 subsystems:
- `B2BLog.musicKit` - MusicKit operations
- `B2BLog.auth` - Authorization flow
- `B2BLog.search` - Search operations and performance
- `B2BLog.playback` - Playback state and user actions
- `B2BLog.ui` - UI interactions
- `B2BLog.network` - API calls
- `B2BLog.ai` - AI/Persona operations
- `B2BLog.session` - Session management
- `B2BLog.general` - General app operations

#### Performance Optimizations
- **Search Debouncing**: 0.75s delay to reduce API calls
- **Non-blocking UI**: All heavy operations run on background queues
- **Lazy Loading**: Search results use LazyVStack for memory efficiency
- **Image Caching**: AsyncImage with proper sizing for artwork

## Testing

The project uses Swift Testing framework (not XCTest) with 17 test files:

```bash
# Run all tests
xcodebuild test -project Back2Back.xcodeproj -scheme Back2Back \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

Comprehensive test coverage includes:
- **Authorization**: MusicAuthViewModelTests
- **Search**: MusicSearchViewModelTests with debouncing tests
- **Music Services**: MusicServiceTests
- **Session Management**: SessionServiceTests, SessionViewModelTests
  - Track matching with normalization tests
  - Unicode and diacritic handling
  - Featuring artist variations
  - Confidence scoring and threshold logic
- **Personas**: PersonaServiceTests, PersonasViewModelTests
- **Song Cache**: PersonaSongCacheServiceTests
  - 24-hour expiration tests
  - Multi-persona isolation tests
- **OpenAI Integration**: OpenAIClientTests, OpenAISongSelectionTests, OpenAIModelsTests
- **Models**: MusicModelsTests
- **Environment**: EnvironmentServiceTests
- **Configuration**: AIModelConfigTests

## Troubleshooting

### Common Issues

#### "Failed to request developer token"
- Ensure MusicKit is enabled in App Services (not Capabilities)
- Verify Bundle ID matches exactly
- Must test on physical device, not simulator
- Check Apple Music privacy policy is accepted

#### AI Not Selecting Songs
- Verify OpenAI API key is correctly configured in `Secrets.swift`
- Check Console.app logs filtered by "Back2Back" subsystem "ai"
- Ensure internet connection is active
- Check OpenAI API account has sufficient credits

#### Song Matching Failures
- Check logs for "No good match found" warnings
- AI will automatically retry with a different recommendation
- If persistent, persona may be too narrow (try broader style guide)
- Unicode apostrophes and special characters are normalized automatically

#### Search Not Working
- Verify Apple Music subscription is active
- Check internet connection
- Review Console.app logs filtered by "Back2Back" subsystem "musicKit"

#### No Audio Playback
- Ensure device volume is up
- Check Control Center for audio routing
- Verify background audio is enabled in Info.plist
- Try calling prepareToPlay() before queueing songs

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Follow existing code patterns and logging conventions
4. Ensure all tests pass
5. Commit your changes with descriptive messages
6. Push to your branch and create a Pull Request

### Development Guidelines
- Use `B2BLog` for all logging (no print statements)
- Follow Swift 6 concurrency patterns
- Test on physical devices with Apple Music
- Keep UI responsive with background processing
- Document complex logic with inline comments

## Recent Updates (September-October 2025)

### MVVM Architecture Refactoring (PRs #56, #57, #66, #73, #75, #76, October 2025)
Complete architecture cleanup and modernization:
- **Single Source of Truth**: Consolidated SessionState into SessionService
- **Eliminated Dual @Observable**: Merged duplicate observable patterns
- **Complete MVVM Separation**: Views only observe ViewModels, never Services
- **ServiceContainer**: Centralized dependency injection with environment-based access
- **Granular ViewModels**: Split monolithic ViewModels into focused components
- **Dead Code Removal**: Cleaned up obsolete patterns and files
- **Benefits**: Clearer data flow, easier testing, consistent patterns

### Comprehensive Testing Upgrade (PR #77, October 2025)
Professional-grade testing infrastructure:
- **258 passing tests** (100% success rate)
- **Protocol-based DI**: All services injectable for testing
- **Complete Mocks**: MockMusicService, MockAIRecommendationService, MockSessionStateManager, etc.
- **TestFixtures**: Consistent test data across all tests
- **OpenAI Safety**: Prevents accidental network calls during tests
- **Testing Documentation**: Comprehensive safety guidelines

### Task Cancellation Improvements (PR #78, October 2025)
Proper Swift concurrency patterns:
- **Native Cancellation**: Replaced custom task ID tracking with Swift task cancellation
- **Eliminated Race Conditions**: Task.isCancelled properly isolates tasks
- **Cleaner Code**: Removed complex validation logic
- **More Reliable**: Native Swift cancellation is better tested

### Persona Song Cache UI (PR #83, October 2025)
Visual cache management:
- **Cache Viewer**: See all cached songs per persona
- **Editor Interface**: Remove individual songs from cache
- **Visual Feedback**: Clear display of cache state
- **Debug Tools**: Enhanced cache inspection capabilities

### First Song Pre-caching (PR #82, October 2025)
Instant "AI Starts" playback:
- **Background Pre-fetching**: AI selects first song before user taps button
- **Eliminates Wait Time**: Instant playback when starting with AI
- **Dedicated Logging**: FirstSelectionCache category for debugging
- **Seamless UX**: No more waiting for AI to think on first selection

### Count-Based LRU Cache (PR #80, October 2025)
Replaced time-based cache with count-based:
- **LRU Eviction**: Keeps most recent N songs (default: 50)
- **Configurable**: User adjustable from 10-500 songs
- **Predictable**: Behavior independent of session frequency
- **Memory Efficient**: Bounded cache size prevents unbounded growth

### Dynamic Direction Change Button (PR #38, October 2025)
Intelligent session steering with AI-powered suggestions:
- **Contextual Analysis**: GPT-5-mini examines session history to identify patterns
- **Contrasting Suggestions**: Proposes dramatic direction changes (different eras, regions, styles)
- **Smart Labels**: Context-aware button text like "West Coast vibes", "Downtempo shift"
- **Automatic Updates**: Regenerates when songs play or button is tapped

### Simplified Queue Management (PR #36, October 2025)
Complete overhaul for smoother playback experience:
- **95% Queueing**: Songs queued to MusicKit at 95% instead of manual stop at 97%
- **Natural Transitions**: MusicKit handles fade-outs automatically
- **Fixed Turn Logic**: Correct queue status based on current turn state
- **Benefits**: Songs play to completion, smoother transitions, simpler code

### Interactive Playback Controls (PR #27, September 2025)
Full-featured playback control implementation:
- **Live Progress**: 500ms polling for real-time position tracking
- **Interactive Scrubbing**: Tap-to-seek and drag gesture support
- **Skip Controls**: ±15s forward/backward buttons
- **Enhanced UI**: Larger hit areas, visual feedback

### Architecture Refactoring (PRs #23, #25, September 2025)
Major organization improvements:
- **Coordinators**: PlaybackCoordinator, TurnManager, AISongCoordinator
- **Service Layer Split**: MusicKit, Session, OpenAI organized by responsibility
- **Protocol Abstractions**: Testable interfaces for all major services
- **Code Quality**: Reduced from 8 files >300 lines to 0

### AI & UX Enhancements
- **Persona Generation**: Time warnings and streaming progress for style guide creation
- **Song Repetition Prevention**: 24-hour cache prevents persona repeats (PR #19)
- **Track Matching**: Unicode normalization, fuzzy matching, retry logic (PR #17)
- **Pagination**: MusicKit search with pagination support
- **Tap-to-Skip**: Skip to any queued song with a tap

## Future Roadmap

### Phase 1: Performance Enhancements (Next)
- LLM-based music matching implementation
- Improved caching strategies
- Better error recovery

### Phase 2: User Experience
- Session statistics and insights
- Playlist export to Apple Music
- Custom persona templates
- Voice control integration

### Phase 3: Platform Expansion
- Spotify integration
- Crossfade transitions
- BPM detection and matching
- Multi-user collaborative sessions
- Social sharing features

## Legal

- Personas are "inspired by" public figures, not impersonations
- Requires valid Apple Music subscription for playback
- User privacy is respected—no unnecessary data storage
- See LICENSE file for full terms

## Support

For issues, questions, or suggestions:
- Open an issue on GitHub
- Check existing issues for solutions
- Review logs using Console.app with "Back2Back" filter

## License

[Add your license here]

---

Built with SwiftUI, MusicKit, and a passion for collaborative music discovery.