# Back to Back (B2B) — Requirements Document

## Overview
Back to Back (B2B) is an interactive music suggestion app where the user and an AI take turns acting as DJs. The user plays a track, and the AI responds with the next track “back-to-back,” inspired by a selected persona. This creates a collaborative and playful DJ experience where the AI functions as a co-DJ rather than a static recommender.

## Core Concept
- **Turn-based interaction**: The app alternates between the user’s song choice and the AI’s song choice.
- **Persona-driven AI**: The AI selects tracks in the style of an inspirational persona (e.g., “Mark Ronson,” “Albert Einstein,” “1970s NYC crate digger”).
- **Music discovery**: By blending user taste with AI-persona recommendations, the app fosters unexpected but coherent musical journeys.

## Platforms & Technology
- **Platform**: iOS 26 (latest APIs available)
- **Language / Frameworks**:
  - Swift + SwiftUI for app UI
  - MusicKit (Apple Music API) for playback, search, and queue management
  - OpenAI API for LLM-driven persona generation and song recommendations
- **Future consideration**: Optional Spotify API integration (not part of MVP)

## MVP Features
1. **Apple Music Integration**
   - User authentication with Apple Music
   - Ability to search the Apple Music catalog
   - Playback and queue management tied to Apple Music subscription
2. **Persona Library**
   - Preset personas (e.g., Mark Ronson, funk crate digger, etc.)
   - User option to enter a custom persona for the LLM to “research”
   - Clear disclaimers: personas are inspired by public information, not endorsements
3. **Turn-Based Song Selection**
   - User chooses the first song
   - AI suggests and queues the next track
   - Alternating sequence continues
4. **UI (SwiftUI)**
   - Simple interface for:
     - Selecting persona
     - Playing/queuing tracks
     - Switching turns
   - Visual feedback when it’s the AI’s turn vs the user’s turn
5. **LLM Integration**
   - Prompt engineering to generate track suggestions “inspired by” the persona
   - Brief rationale displayed with each AI suggestion (e.g., “This fits the horn section energy of your last pick”)

## User Flow
1. **Login / Setup**
   - User logs in with their Apple Music account via MusicKit.
   - User selects or creates an AI persona to play against.
2. **First Song**
   - User searches for a song and plays it.
   - The song is played back inside the app using Apple Music integration.
3. **AI Turn**
   - While the user’s song is playing, the AI processes:
     - Uses the persona profile + current track to decide the next song.
     - Searches the Apple Music catalog for the best match.
   - The chosen song is queued behind the current song.
4. **Alternating Turns**
   - Once the first song ends, the AI’s pick begins playing automatically.
   - The user is then prompted to select the next track, continuing the back-and-forth cycle.
5. **Session Tracking**
   - Each played track (user + AI) is recorded in the current session history.
   - Future enhancement: add a **“Save as Playlist”** button to export the full session into Apple Music as a playlist.

## Future Enhancements
- **Spotify integration** for broader compatibility
- **Crossfade / BPM-aware transitions** for smoother mixes
- **Deeper persona profiles** (e.g., retrieval from interviews, playlists, or cultural data)
- **Multi-user support**: two humans + one AI, or AI vs AI
- **Voice interaction**: user can verbally pass turns or request commentary
- **Save as Playlist**: allow users to export the full session into a playlist for later listening

## Constraints & Considerations
- **Licensing**: Apple Music playback requires a subscription; app cannot bypass catalog licensing
- **Latency**: AI recommendations must be generated quickly to maintain flow (done during playback)
- **Legal**: Persona feature must avoid impersonation; provide clear disclaimers
- **User privacy**: Ensure user listening history and persona requests are not stored unnecessarily