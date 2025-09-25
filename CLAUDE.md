# Back2Back (B2B) Project Context

## Project Overview
Back2Back is an iOS app that creates an interactive DJ experience where users and AI take turns selecting songs, creating a collaborative back-to-back DJ session. The AI selects tracks based on configurable personas (e.g., "Mark Ronson," "1970s NYC crate digger").

## Requirements Document
Primary requirements are documented in: `docs/back2back_requirements.md`

## Technology Stack
- **Platform**: iOS 18+ (using latest available APIs)
- **Language**: Swift 6+
- **UI Framework**: SwiftUI
- **Music Playback**: Apple MusicKit
- **AI Integration**: OpenAI API for persona-based song recommendations
- **Minimum iOS Version**: iOS 17.0+ (for latest MusicKit features)

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
- Use for generating persona-based song recommendations
- Implement streaming responses for better UX during AI turn

## Core Features (MVP)
1. Apple Music authentication and integration
2. Turn-based song selection (user → AI → user)
3. Persona library with preset and custom options
4. Visual feedback for current turn
5. Session history tracking

## Project Structure
```
Back2Back/
├── Back2Back/           # Main app target
│   ├── Models/         # Data models for songs, personas, sessions
│   ├── Views/          # SwiftUI views
│   ├── Services/       # MusicKit, OpenAI API services
│   ├── ViewModels/     # Business logic and state management
│   └── Utils/          # Helper functions and extensions
├── docs/               # Documentation
└── Back2BackTests/     # Unit tests
```

## Development Guidelines

### MusicKit Setup
1. Enable MusicKit capability in Xcode project settings
2. Add usage description in Info.plist for `NSAppleMusicUsageDescription`
3. Configure proper entitlements for MusicKit

### API Keys Management
- Store OpenAI API keys securely (use Keychain or environment variables)
- Never commit API keys to the repository
- Use configuration files that are gitignored for local development

### Testing Approach
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

# Run tests
xcodebuild test -project Back2Back.xcodeproj -scheme Back2Back -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# Clean build folder
xcodebuild clean -project Back2Back.xcodeproj -scheme Back2Back
```

## Important Notes
- Always test with real Apple Music subscription
- Ensure AI response times don't interrupt music flow
- Keep persona suggestions tasteful and appropriate
- Follow Apple's Human Interface Guidelines for iOS apps