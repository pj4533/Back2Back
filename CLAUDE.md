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

### OpenAI API (Not Yet Implemented)
- Will be used for generating persona-based song recommendations
- Plan to implement streaming responses for better UX during AI turn
- Requires secure API key storage (Keychain recommended)

## Core Features (MVP)

### Currently Implemented
1. **Apple Music authentication and integration** ✅
   - Full MusicAuthorization flow with error handling
   - Settings deep-linking for denied permissions
   - Authorization status tracking via MusicService singleton

2. **Music Search and Playback** ✅
   - Real-time catalog search with 0.75s debouncing
   - ApplicationMusicPlayer integration
   - Queue management
   - Now Playing UI (mini and expanded views)

### Not Yet Implemented
3. **Turn-based song selection (user → AI → user)** ⏳
4. **Persona library with preset and custom options** ⏳
5. **Visual feedback for current turn** ⏳
6. **Session history tracking** ⏳
7. **OpenAI API integration** ⏳

## Project Structure
```
Back2Back/
├── Back2Back/                    # Main app target
│   ├── Back2BackApp.swift       # App entry point with B2BLog initialization
│   ├── ContentView.swift        # Main navigation and auth flow controller
│   ├── Models/
│   │   └── MusicModels.swift   # MusicSearchResult, NowPlayingItem, error types
│   ├── Views/
│   │   ├── MusicAuthorizationView.swift  # Apple Music permission UI
│   │   ├── MusicSearchView.swift         # Search UI with debounced input
│   │   └── NowPlayingView.swift          # Mini/expanded player views
│   ├── Services/
│   │   └── MusicService.swift  # Singleton MusicKit wrapper (@MainActor)
│   ├── ViewModels/
│   │   ├── MusicAuthViewModel.swift      # Auth state management
│   │   └── MusicSearchViewModel.swift    # Search with 0.75s debouncing
│   ├── Utils/
│   │   └── Logger.swift         # B2BLog unified logging system
│   └── Info.plist              # Background audio configuration
├── docs/
│   └── back2back_requirements.md # Original spec (DO NOT MODIFY)
└── Back2BackTests/              # Swift Testing framework tests
    ├── MusicAuthViewModelTests.swift
    ├── MusicSearchViewModelTests.swift
    ├── MusicServiceTests.swift
    └── MusicModelsTests.swift
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
- Service layer (MusicServiceTests)
- Model validation (MusicModelsTests)

## Important Notes
- Always test with real Apple Music subscription
- MusicKit requires physical device (simulator won't work)
- Ensure AI response times don't interrupt music flow (when implemented)
- Keep persona suggestions tasteful and appropriate (future feature)
- Follow Apple's Human Interface Guidelines for iOS apps
- Use B2BLog for all logging - no print statements
- Maintain non-blocking UI with proper concurrency patterns