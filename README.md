# Back2Back (B2B)

An interactive iOS DJ experience where users and AI take turns selecting songs, creating a collaborative back-to-back DJ session.

## Overview

Back2Back transforms music listening into a collaborative DJ experience. Users play songs, and an AI DJ responds with complementary tracks based on customizable personas (like "Mark Ronson" or "1970s NYC crate digger"). It's not just a playlist generator—it's your AI co-DJ partner.

## Current Implementation Status

### Implemented Features
- **Apple Music Integration**
  - Full MusicKit authorization flow with proper error handling
  - Real-time catalog search with performance-optimized debouncing (0.75s)
  - Music playback via ApplicationMusicPlayer
  - Now Playing view with mini/expanded player UI
  - Queue management and playback controls

- **Core Infrastructure**
  - Comprehensive logging system using OSLog with subsystem categorization
  - Swift 6+ concurrency with async/await patterns
  - Non-blocking UI updates using Swift Concurrency
  - MVVM architecture with @Observable ViewModels

- **User Interface**
  - Clean SwiftUI-based interface
  - Authorization view with Settings deep-linking
  - Search view with real-time results
  - Now Playing mini-player and expanded view
  - Smooth animations and transitions

### Not Yet Implemented (Planned Features)
- **AI Persona System** - OpenAI integration for persona-based recommendations
- **Turn-based DJ Logic** - Alternating song selection between user and AI
- **Persona Library** - Preset and custom persona management
- **Session History** - Track and display DJ session history
- **Playlist Export** - Save sessions as Apple Music playlists
- **Advanced Transitions** - Crossfade and BPM-aware mixing

## Requirements

- **iOS Version**: iOS 17.0+ (required for latest MusicKit features)
- **Xcode**: 16.0+ (for Swift 6 support)
- **Apple Music**: Active subscription required for full functionality
- **Device**: Physical iOS device (MusicKit doesn't work in simulator)
- **Developer Account**: Apple Developer account with MusicKit service enabled

## Installation

### 1. Clone the Repository
```bash
git clone https://github.com/yourusername/Back2Back.git
cd Back2Back
```

### 2. Apple Developer Configuration

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

### 3. Build and Run

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
│   ├── ContentView.swift      # Main navigation and authorization flow
│   ├── Models/
│   │   └── MusicModels.swift  # Data models for music items and errors
│   ├── Services/
│   │   └── MusicService.swift # MusicKit API wrapper and playback control
│   ├── ViewModels/
│   │   ├── MusicAuthViewModel.swift   # Authorization state management
│   │   └── MusicSearchViewModel.swift # Search and playback logic
│   ├── Views/
│   │   ├── MusicAuthorizationView.swift # Authorization UI
│   │   ├── MusicSearchView.swift        # Search interface
│   │   └── NowPlayingView.swift         # Playback controls
│   ├── Utils/
│   │   └── Logger.swift       # Unified OSLog-based logging system
│   └── Info.plist             # Background audio configuration
├── Back2BackTests/            # Swift Testing framework tests
├── docs/
│   └── back2back_requirements.md # Original project specification
└── CLAUDE.md                  # Development guidelines and context
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
- Authorization handling
- Catalog search with caching
- Playback control via ApplicationMusicPlayer
- Queue management
- Real-time playback state updates

#### Logging System (B2BLog)
Comprehensive logging with subsystems:
- `B2BLog.musicKit` - MusicKit operations
- `B2BLog.auth` - Authorization flow
- `B2BLog.search` - Search operations and performance
- `B2BLog.playback` - Playback state and user actions
- `B2BLog.ui` - UI interactions
- `B2BLog.network` - API calls
- `B2BLog.ai` - AI/Persona operations (future)
- `B2BLog.session` - Session management (future)

#### Performance Optimizations
- **Search Debouncing**: 0.75s delay to reduce API calls
- **Non-blocking UI**: All heavy operations run on background queues
- **Lazy Loading**: Search results use LazyVStack for memory efficiency
- **Image Caching**: AsyncImage with proper sizing for artwork

## Testing

The project uses Swift Testing framework (not XCTest):

```bash
# Run all tests
xcodebuild test -project Back2Back.xcodeproj -scheme Back2Back \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

Current test coverage includes:
- `MusicAuthViewModelTests` - Authorization flow testing
- `MusicSearchViewModelTests` - Search logic and debouncing
- `MusicServiceTests` - Service layer testing
- `MusicModelsTests` - Model validation

## Troubleshooting

### Common Issues

#### "Failed to request developer token"
- Ensure MusicKit is enabled in App Services (not Capabilities)
- Verify Bundle ID matches exactly
- Must test on physical device, not simulator
- Check Apple Music privacy policy is accepted

#### Search Not Working
- Verify Apple Music subscription is active
- Check internet connection
- Review Console.app logs filtered by "Back2Back"

#### No Audio Playback
- Ensure device volume is up
- Check Control Center for audio routing
- Verify background audio is enabled in Info.plist

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

## Future Roadmap

### Phase 1: AI Integration (Next)
- OpenAI API integration
- Persona creation and management
- Turn-based song selection logic
- AI reasoning display

### Phase 2: Enhanced Features
- Session history and statistics
- Playlist export functionality
- Multiple persona profiles
- Recommendation tuning

### Phase 3: Advanced Capabilities
- Spotify integration
- Crossfade transitions
- BPM detection and matching
- Voice control
- Multi-user sessions

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