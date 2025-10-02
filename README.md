# Back2Back (B2B)

An interactive iOS DJ experience where users and AI take turns selecting songs, creating a collaborative back-to-back DJ session.

## Overview

Back2Back transforms music listening into a collaborative DJ experience. Users play songs, and an AI DJ responds with complementary tracks based on customizable personas (like "Mark Ronson" or "1970s NYC crate digger"). It's not just a playlist generator—it's your AI co-DJ partner.

## Current Implementation Status

### Fully Implemented Features ✅

#### Apple Music Integration
- Full MusicKit authorization flow with proper error handling
- Real-time catalog search with performance-optimized debouncing (0.75s)
- Music playback via ApplicationMusicPlayer with prepareToPlay() for queue readiness
- Now Playing view with mini/expanded player UI
- Queue management and playback controls
- Tap-to-skip functionality for queued songs

#### AI-Powered DJ Experience
- **OpenAI Integration**: GPT-5 Responses API for intelligent song selection
- **Persona System**: Create, edit, and manage custom DJ personas
  - Default personas: "Rare Groove Collector", "Modern Electronic DJ"
  - Configurable style guides for unique AI behavior
  - Persistent storage via UserDefaults
- **Turn-based Logic**: Automatic alternation between user and AI selections
- **Intelligent Prefetching**: AI pre-selects next song while current song plays
- **AI Model Configuration**: Choose between GPT-5, GPT-5 Mini, GPT-5 Nano with adjustable reasoning levels

#### Advanced Song Matching
- **StringBasedMusicMatcher**: Fuzzy matching with sophisticated normalization
  - Unicode normalization (curly quotes, diacritics)
  - Artist variations (featuring artists, "The" prefix, ampersands, abbreviations)
  - Title cleaning (parentheticals, part numbers, remaster tags)
  - Confidence scoring requiring BOTH artist AND title matches
- **AI Retry Logic**: Automatic retry when no good match is found
- **Protocol-based Architecture**: Easy to swap for LLM-based matching in future

#### Session Management
- **Full Session History**: Track all played and queued songs
- **Queue Status Tracking**: playing, played, upNext, queuedIfUserSkips
- **Turn Visualization**: Clear indication of whose turn (User/AI)
- **Session Persistence**: Maintains state throughout app lifecycle

#### Time-Based Repetition Prevention
- **24-Hour Song Cache**: Prevents personas from repeating songs across sessions
- **Per-Persona Tracking**: Each persona has independent cache
- **Automatic Expiration**: Songs older than 24 hours are automatically excluded
- **Debug Tools**: Clear cache button in configuration settings

#### Core Infrastructure
- Comprehensive logging system using OSLog with 9 subsystem categories
- Swift 6+ concurrency with async/await patterns throughout
- Non-blocking UI updates using Swift Concurrency
- MVVM architecture with @Observable ViewModels
- Secure API key management via EnvironmentService

#### User Interface
- Tab-based navigation: Session, Personas, Configuration
- Clean SwiftUI-based interface with smooth animations
- Authorization view with Settings deep-linking
- Real-time search with debounced results
- Now Playing mini-player and expanded view
- Session view with history and queue display
- Persona management with create/edit/delete
- Configuration UI for AI model settings

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
│   │   ├── AIModelConfig.swift         # AI configuration and persistence
│   │   ├── OpenAIModels.swift          # OpenAI API types
│   │   ├── OpenAIModels+Core.swift     # Base request/response types
│   │   ├── OpenAIModels+Components.swift  # Message, ToolCall, etc.
│   │   └── OpenAIModels+Streaming.swift   # Streaming response types
│   ├── Services/
│   │   ├── MusicService.swift            # MusicKit API wrapper
│   │   ├── SessionService.swift          # DJ session state management
│   │   ├── PersonaService.swift          # Persona CRUD operations
│   │   ├── PersonaSongCacheService.swift # 24hr repetition prevention
│   │   ├── EnvironmentService.swift      # Secure API key management
│   │   ├── OpenAIClient.swift            # Core OpenAI HTTP client
│   │   ├── OpenAIClient+Responses.swift  # Responses API
│   │   ├── OpenAIClient+Streaming.swift  # Streaming handlers
│   │   ├── OpenAIClient+StreamHelpers.swift # Stream parsing
│   │   ├── OpenAIClient+SongSelection.swift # Song recommendation
│   │   ├── OpenAIClient+Persona.swift    # Persona generation
│   │   └── MusicMatching/
│   │       ├── MusicMatchingProtocol.swift      # Matcher interface
│   │       ├── StringBasedMusicMatcher.swift    # Fuzzy string matching
│   │       └── LLMBasedMusicMatcher.swift       # Future LLM matcher
│   ├── ViewModels/
│   │   ├── MusicAuthViewModel.swift      # Authorization state
│   │   ├── MusicSearchViewModel.swift    # Search with debouncing
│   │   ├── SessionViewModel.swift        # DJ session logic
│   │   ├── NowPlayingViewModel.swift     # Playback state
│   │   ├── PersonasViewModel.swift       # Persona list management
│   │   └── PersonaDetailViewModel.swift  # Persona editing
│   ├── Views/
│   │   ├── MusicAuthorizationView.swift  # Authorization UI
│   │   ├── MusicSearchView.swift         # Search interface
│   │   ├── NowPlayingView.swift          # Playback controls
│   │   ├── SessionView.swift             # DJ session UI
│   │   ├── PersonasListView.swift        # Persona management
│   │   ├── PersonaDetailView.swift       # Edit/create persona
│   │   └── ConfigurationView.swift       # AI settings and debug
│   ├── Utils/
│   │   └── Logger.swift       # OSLog-based logging (9 subsystems)
│   └── Info.plist             # Background audio configuration
├── Back2BackTests/            # Swift Testing framework (17 test files)
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

#### MusicService
Central service managing all MusicKit interactions:
- Authorization handling with Settings deep-linking
- Catalog search with TopResults prioritization
- Playback control via ApplicationMusicPlayer
- Queue management with prepareToPlay()
- Real-time playback state updates

#### SessionService
Manages the back-to-back DJ session:
- Session history tracking with metadata
- Queue management (upNext, queuedIfUserSkips)
- Turn management (User/AI alternation)
- Currently playing song tracking
- Song status updates (playing, played)

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

#### OpenAIClient
Handles all AI interactions:
- GPT-5 Responses API integration
- Song selection with persona context
- Streaming persona generation
- Configurable models and reasoning levels

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

## Recent Updates (September 2025)

### Time-Based Song Repetition Prevention (PR #19)
Implemented 24-hour cache system to prevent personas from repeating songs:
- PersonaSongCacheService with automatic expiration
- Per-persona song tracking in UserDefaults
- AI prompts include exclusion list
- Debug UI to clear cache

### Tap-to-Skip Functionality
Users can now tap any queued song to skip ahead:
- Tap gesture on SessionSongRow
- Automatic queue management
- Smooth transition handling

### Intelligent Track Matching (PR #17)
Enhanced verification between AI recommendations and Apple Music:
- Unicode normalization (curly quotes, diacritics)
- Artist/title normalization (featuring, "The" prefix, ampersands)
- Parenthetical stripping (Remastered, Live, Part numbers)
- Confidence scoring requiring BOTH matches
- AI retry logic for failed matches
- Protocol-based architecture for future LLM matching

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