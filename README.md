# Back2Back

An iOS app where you and an AI take turns DJing—creating a collaborative music session powered by Apple Music and OpenAI.

## Core Features

### Music Playback
- Apple Music integration with full playback controls
- Interactive progress bar with scrubbing and skip controls (±15s)
- Automatic queue management with smooth transitions
- Tap-to-skip functionality for queued songs
- Now Playing view (mini and expanded)

### AI DJ Partner
- **Turn-Based Sessions**: You pick a song, AI picks the next one, and so on
- **Custom Personas**: Create AI DJs with different styles (e.g., "Rare Groove Collector", "Modern Electronic DJ")
- **Smart Song Selection**: AI uses GPT-5 to choose songs that match the persona and flow with the session
- **Direction Changes**: During your turn, get AI-generated suggestions to shift the session's vibe (e.g., "West Coast vibes", "60s garage rock")
- **AI Starts**: Pre-cached first song for instant playback when starting with AI
- **Song History**: Full session tracking with favorites support

### Intelligent Features
- **Song Matching**: Sophisticated fuzzy matching handles artist variations, unicode characters, and different versions
- **Repetition Prevention**: LRU cache (default: 50 songs) prevents personas from repeating recent selections
- **Dynamic Status Messages**: Persona-specific AI thinking messages while selecting songs
- **Configurable AI Models**: Choose between GPT-5, GPT-5 Mini, or GPT-5 Nano with adjustable reasoning levels

## Requirements

- iOS 17.0+
- Active Apple Music subscription
- OpenAI API key
- Physical iOS device (MusicKit requires real hardware)
- Apple Developer account with MusicKit enabled

## Setup

1. **Clone and configure API key**:
   ```bash
   git clone https://github.com/yourusername/Back2Back.git
   cd Back2Back
   cp Back2Back/SecretsTemplate.swift Back2Back/Secrets.swift
   ```
   Edit `Secrets.swift` and add your OpenAI API key.

2. **Enable MusicKit**:
   - Go to [Apple Developer Portal](https://developer.apple.com)
   - Enable "MusicKit" under App Services for your App ID

3. **Build and run**:
   - Open `Back2Back.xcodeproj` in Xcode
   - Set your Team in Signing & Capabilities
   - Run on a physical device (Cmd+R)

## Architecture

The app uses **MVVM architecture** with Swift 6 concurrency:
- **Models**: Music data, personas, AI configurations
- **Views**: SwiftUI-based UI (Session, Personas, Configuration tabs)
- **ViewModels**: Business logic and state management
- **Services**: MusicKit, OpenAI, Session management
- **Coordinators**: Playback monitoring, turn management, AI song selection

Key patterns:
- Protocol-oriented design for testability (258 passing tests)
- Dependency injection via ServiceContainer
- Non-blocking UI with async/await throughout

## Testing

Run tests with:
```bash
xcodebuild test -project Back2Back.xcodeproj -scheme Back2Back \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

258 passing tests covering music services, session management, AI integration, and song matching.

## Troubleshooting

**"Failed to request developer token"**
- Enable MusicKit in App Services (not Capabilities) in Apple Developer Portal
- Must run on physical device (not simulator)
- Ensure Apple Music privacy policy is accepted

**AI not selecting songs**
- Verify OpenAI API key in `Secrets.swift`
- Check Console.app logs (subsystem: "Back2Back", category: "ai")
- Ensure OpenAI account has credits

**No audio playback**
- Check device volume and audio routing
- Verify Apple Music subscription is active

---

Built with SwiftUI, MusicKit, and OpenAI.