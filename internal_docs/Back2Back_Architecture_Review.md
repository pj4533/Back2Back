# Back2Back iOS App - Architecture Review

**Date**: October 13, 2025
**Reviewer**: Claude Code (Senior Software Architect)
**Codebase Version**: Main branch (latest commit: b71e136)

---

## Executive Summary

The Back2Back iOS app demonstrates **solid foundational architecture** with clear service layer separation, protocol-oriented design, and modern Swift concurrency patterns. The codebase has been through multiple refactoring phases (PRs #20, #23, #25) which successfully extracted coordinators, split services by responsibility, and improved separation of concerns.

### Overall Architecture Health: **B+ (Good, with room for improvement)**

**Strengths:**
- Clear service layer with single-responsibility principle
- Protocol-based abstractions for testability
- Modern @Observable pattern for SwiftUI state management
- Comprehensive logging system
- Good use of async/await throughout
- Facade pattern effectively simplifies complex subsystems (MusicService)

**Primary Concerns:**
- **Singleton overuse** creates hidden dependencies and testing challenges
- **State synchronization complexity** between multiple services
- **Task cancellation patterns** are inconsistent and error-prone
- **Protocol violations** - protocols defined but often bypassed
- **Service coupling** through shared singleton access
- **Implicit dependencies** make dependency graph unclear

**Impact**: While the app works correctly, technical debt is accumulating in state management and service coordination. As features grow, the singleton-heavy architecture will become increasingly difficult to maintain, test, and reason about.

---

## 1. Critical Issues

### 1.1 Singleton Anti-Pattern Proliferation
**Severity**: Critical
**Impact**: Testability, Maintainability, Hidden Dependencies

**Problem**:
The codebase has 11+ singleton services, all using `.shared` static properties:
- `SessionService.shared`
- `MusicService.shared`
- `PersonaService.shared`
- `OpenAIClient.shared`
- `EnvironmentService.shared`
- `PersonaSongCacheService.shared`
- `StatusMessageService.shared`
- `ToastService.shared`
- `FavoritesService.shared`
- `SongErrorLoggerService.shared`
- `SessionViewModel.shared`

**Why It's Problematic**:
1. **Hidden Dependencies**: Any code can access any service without declaring dependencies
   ```swift
   // AISongCoordinator.swift:18
   private let openAIClient = OpenAIClient.shared
   private let sessionService = SessionService.shared
   private let environmentService = EnvironmentService.shared

   // These are NOT in the initializer, making dependencies invisible
   ```

2. **Testing Nightmare**: Cannot inject mocks without complex setup
   ```swift
   // SessionViewModel.swift - hardcoded dependencies
   private let musicService: MusicService
   private let sessionService: SessionService

   init(...) {
       self.musicService = musicService ?? MusicService.shared  // Still defaults to singleton
       self.sessionService = sessionService ?? SessionService.shared
   }
   ```

3. **Circular Dependency Risk**: Services reference each other via singletons
   ```swift
   // SessionService → PersonaService.shared
   // PersonaService → StatusMessageService.shared
   // Multiple services → ToastService.shared
   ```

4. **Impossible to Reset State**: Tests cannot cleanly reset between runs
5. **Global Mutable State**: All singletons are @Observable with mutable state

**Files Affected**:
- All Services/ files
- All Coordinators/ files
- SessionViewModel.swift
- Most ViewModels

**Recommended Solution**:
1. **Dependency Injection Container**: Use a DI framework or simple container pattern
2. **Environment-based injection**: Pass services through SwiftUI Environment
3. **Protocol + Constructor Injection**: Make all dependencies explicit
4. **Factory Pattern**: For creating service graphs

**Example Refactor**:
```swift
// BEFORE (current)
final class AISongCoordinator {
    private let openAIClient = OpenAIClient.shared
    private let sessionService = SessionService.shared

    init() {}
}

// AFTER (proposed)
final class AISongCoordinator {
    private let openAIClient: AIRecommendationServiceProtocol
    private let sessionService: SessionStateManagerProtocol

    init(
        openAIClient: AIRecommendationServiceProtocol,
        sessionService: SessionStateManagerProtocol
    ) {
        self.openAIClient = openAIClient
        self.sessionService = sessionService
    }
}
```

---

### 1.2 Task Cancellation Race Conditions
**Severity**: Critical
**Impact**: Correctness, User Experience, Resource Leaks

**Problem**:
The task cancellation pattern in `AISongCoordinator` uses a "task ID superseding" approach instead of actual task cancellation, which creates race conditions.

**Evidence** (AISongCoordinator.swift:226-239):
```swift
func startPrefetch(queueStatus: QueueStatus, directionChange: DirectionChange? = nil) {
    // Don't cancel existing task here - just invalidate its ID
    // This prevents race conditions where the new task checks Task.isCancelled
    if prefetchTask != nil {
        B2BLog.session.debug("Superseding existing AI prefetch task with new task")
    }

    let taskId = UUID()
    prefetchTaskId = taskId  // New ID invalidates old task

    prefetchTask = Task.detached { [weak self] in
        await self?.prefetchAndQueueAISong(queueStatus: queueStatus, directionChange: directionChange, taskId: taskId)
    }
}
```

**Why This Is Problematic**:
1. **Old tasks continue running**: The previous task keeps consuming resources until it naturally completes or checks `taskId`
2. **Multiple checkpoints required**: The code has 10+ places checking `taskId == prefetchTaskId`
3. **Timing-dependent**: If taskId changes between checks, partial work may complete
4. **Resource waste**: Network requests, AI calls continue even when user moves on
5. **Potential queue corruption**: Old task might still call `queueSong()` after being invalidated

**Lines with Task ID checks** (AISongCoordinator.swift):
- Line 102, 114, 130, 145, 154, 170, 183, 195 - scattered throughout operation

**The Real Problem**:
The comment states "This prevents race conditions where the new task checks Task.isCancelled" but this is backwards - the proper solution is to fix the retry logic to handle cancellation correctly, not work around it.

**Evidence of the workaround** (PR #38 commit messages):
- b220ef5: "Fixed cancellation state bleeding between old and new tasks"
- d79c19f: "Added Task.isCancelled checks to stop retry loops"

**Impact**:
- When user taps direction change multiple times rapidly, multiple AI song selections run in parallel
- Old tasks may queue songs that get immediately cleared
- Wasted API calls cost money
- Battery drain from unnecessary work

**Recommended Solution**:
1. **Actually cancel tasks**: Call `prefetchTask?.cancel()` immediately
2. **Fix AIRetryStrategy**: Make it properly handle `Task.isCancelled`
3. **Structured concurrency**: Use `withTaskCancellationHandler` for cleanup
4. **Single checkpoint**: Check cancellation at start of operations, not throughout

**Example Fix**:
```swift
func startPrefetch(queueStatus: QueueStatus, directionChange: DirectionChange? = nil) {
    // Properly cancel old task
    prefetchTask?.cancel()

    prefetchTask = Task {
        await withTaskCancellationHandler {
            // Work here
            guard !Task.isCancelled else { return }
            await prefetchAndQueueAISong(queueStatus: queueStatus, directionChange: directionChange)
        } onCancel: {
            // Cleanup here
            sessionService.setAIThinking(false)
        }
    }
}

// In AIRetryStrategy - handle cancellation properly
static func executeWithRetry<T>(...) async throws -> T? {
    // Check once at start, let Swift handle rest
    guard !Task.isCancelled else { return nil }

    do {
        return try await operation()
    } catch is CancellationError {
        // Don't retry cancellations
        return nil
    } catch {
        // Retry other errors
        return try await performRetries(...)
    }
}
```

---

### 1.3 State Synchronization Complexity
**Severity**: Critical
**Impact**: Correctness, Maintainability, Bugs

**Problem**:
Session state is split across **5 separate services** with no single source of truth:

1. **SessionService**: `currentTurn`, `isAIThinking`, `nextAISong`
2. **SessionHistoryService**: `sessionHistory`, `currentlyPlayingSongId`
3. **QueueManager**: `songQueue`
4. **MusicPlaybackService**: `currentlyPlaying`, `playbackState`
5. **TurnManager**: Logic for turn transitions (no state!)

**Why This Is Problematic**:

**Example 1: Turn Management Confusion** (SessionService.swift:96-107)
```swift
// In updateCurrentlyPlayingSong() - turn logic scattered
if removedSong.queueStatus == .upNext {
    let newTurn = removedSong.selectedBy == .user ? TurnType.ai : TurnType.user
    currentTurn = newTurn
} else if removedSong.queueStatus == .queuedIfUserSkips {
    currentTurn = .user  // Force to user
}
```

**Same logic duplicated** in SessionService.swift:145-155 (moveQueuedSongToHistory)

**Example 2: Inconsistent State Updates**
```swift
// SessionService.swift:79 - Strange pattern
func updateCurrentlyPlayingSong(songId: String) {
    // Check history first
    if let _ = historyService.getSong(withId: UUID()) {  // ← BUG: Creates random UUID!
        historyService.updateCurrentlyPlayingSong(songId: songId)
        return
    }
    // Then check queue...
}
```

This creates a **logical bug** - it creates a new UUID() instead of using an actual song ID, so this check always fails.

**Example 3: Playback State Synchronization**

PlaybackCoordinator must manually sync state:
```swift
// PlaybackCoordinator.swift:114
sessionService.updateCurrentlyPlayingSong(songId: currentSongId)
```

But SessionService delegates to multiple sub-services, each with their own state.

**Evidence of Complexity**:
- SessionService has 194 lines but delegates everything
- Turn logic duplicated in 3 places (SessionService lines 96-107, 145-155, TurnManager)
- 4 services track "currently playing" in different ways

**Recommended Solution**:

**Option A: Single Session State Manager** (Preferred)
```swift
// NEW: SessionState.swift - Single source of truth
@MainActor
@Observable
final class SessionState {
    // All session state in one place
    private(set) var currentTurn: TurnType = .user
    private(set) var isAIThinking: Bool = false
    private(set) var history: [SessionSong] = []
    private(set) var queue: [SessionSong] = []
    private(set) var currentlyPlayingSongId: UUID?

    // Computed properties
    var currentlyPlayingSong: SessionSong? {
        history.first { $0.id == currentlyPlayingSongId }
    }

    // State transitions are methods
    func startSong(_ song: SessionSong) {
        history.append(song)
        currentlyPlayingSongId = song.id
        advanceTurn(basedOn: song)
    }

    private func advanceTurn(basedOn song: SessionSong) {
        // Turn logic in ONE place
        currentTurn = song.selectedBy == .user ? .ai : .user
    }
}
```

**Option B: Event-Driven State**
Use events/notifications to coordinate state changes instead of direct calls

---

### 1.4 Protocol Usage Inconsistency
**Severity**: High
**Impact**: Architecture Integrity, Testability

**Problem**:
The codebase defines protocols for abstraction but frequently bypasses them by using concrete types directly.

**Example 1: SessionViewModel**
```swift
// SessionViewModel.swift:22-23
// Comment claims to use protocols, but actually uses concrete types!
// "Use concrete @Observable types for SwiftUI observation to work"
// "Protocols break observation chain since they can't be @Observable"
private let musicService: MusicService  // NOT MusicServiceProtocol
private let sessionService: SessionService  // NOT SessionStateManagerProtocol
```

The **comment admits the architecture violation** - protocols can't be @Observable, so we use concrete types. This defeats the purpose of having protocols.

**Example 2: AISongCoordinator**
```swift
// AISongCoordinator.swift:18-20
private let openAIClient = OpenAIClient.shared  // Direct singleton access
private let sessionService = SessionService.shared
private let environmentService = EnvironmentService.shared

// But constructor DOES accept protocol for matcher!
init(musicMatcher: MusicMatchingProtocol? = nil) {
    if let matcher = musicMatcher {
        self.musicMatcher = matcher  // Injected
    } else {
        self.musicMatcher = Self.createMatcher(...)  // Factory
    }
}
```

Why is `musicMatcher` injectable but not the other dependencies?

**Example 3: Protocols Exist But Unused**

Three protocols defined:
- `MusicServiceProtocol` (27 lines)
- `SessionStateManagerProtocol` (29 lines)
- `AIRecommendationServiceProtocol` (14 lines)

But only MockXXX test classes implement them. Production code uses concrete types.

**Why This Is Problematic**:
1. **False abstraction**: Protocols exist but don't abstract anything
2. **Testing harder than it should be**: Must use real implementations
3. **Architecture documentation lies**: Protocols suggest design that doesn't exist
4. **SwiftUI limitation exposed**: Can't use protocols with @Observable

**Recommended Solution**:

**Option A: Remove Protocols** (Honest approach)
If we can't actually use them due to SwiftUI constraints, delete them. Use concrete types everywhere and acknowledge the coupling.

**Option B: ViewModels as Adapters** (Proper approach)
```swift
// SessionViewModel becomes the observable adapter
@MainActor
@Observable
final class SessionViewModel {
    // Internal non-observable protocol properties
    private let musicService: MusicServiceProtocol
    private let sessionService: SessionStateManagerProtocol

    // Published computed properties for SwiftUI
    var currentTurn: TurnType { sessionService.currentTurn }
    var isAIThinking: Bool { sessionService.isAIThinking }
    var sessionHistory: [SessionSong] { sessionService.sessionHistory }

    init(
        musicService: MusicServiceProtocol = MusicService.shared,
        sessionService: SessionStateManagerProtocol = SessionService.shared
    ) {
        self.musicService = musicService
        self.sessionService = sessionService

        // Observe underlying services and trigger objectWillChange
        setupObservation()
    }
}
```

**Option C: Extract UI State** (Compromise)
Keep business logic behind protocols, but have separate @Observable UI state classes

---

## 2. Major Concerns

### 2.1 Implicit State Dependencies in PlaybackCoordinator
**Severity**: High
**Impact**: Maintainability, Bugs, Testability

**Problem**:
`PlaybackCoordinator` monitors playback state and coordinates song transitions, but it relies on implicit side effects and callback closures instead of clear state management.

**Evidence** (PlaybackCoordinator.swift):
```swift
// Line 29: Callback closure instead of event/protocol
var onSongEnded: (() async -> Void)?

// Line 51-53: Setup callback in SessionViewModel
self.playbackCoordinator.onSongEnded = { [weak self] in
    await self?.handleSongEnded()
}
```

**Why This Is Problematic**:
1. **Hidden coupling**: PlaybackCoordinator → SessionViewModel through closure
2. **Cannot inject for testing**: Closure set after initialization
3. **Weak reference dance**: `[weak self]` everywhere
4. **Implicit initialization order**: Must set callback before coordinator starts working
5. **No protocol contract**: Callback signature is arbitrary

**Better Approach** (Protocol + Delegate):
```swift
@MainActor
protocol PlaybackCoordinatorDelegate: AnyObject {
    func playbackCoordinator(_ coordinator: PlaybackCoordinator, didEndSong song: Song)
    func playbackCoordinator(_ coordinator: PlaybackCoordinator, didTransitionTo song: Song)
}

final class PlaybackCoordinator {
    weak var delegate: PlaybackCoordinatorDelegate?

    init(delegate: PlaybackCoordinatorDelegate? = nil) {
        self.delegate = delegate
    }

    private func handleEndOfSong() async {
        await delegate?.playbackCoordinator(self, didEndSong: currentSong)
    }
}
```

**Or better yet** (Event-driven):
```swift
enum PlaybackEvent {
    case songEnded(Song)
    case songTransitioned(from: Song, to: Song)
    case playbackProgress(Double)
}

final class PlaybackCoordinator {
    let events = AsyncStream<PlaybackEvent>

    // Coordinator publishes events, ViewModel subscribes
}
```

---

### 2.2 SessionService as God Object
**Severity**: High
**Impact**: Maintainability, Single Responsibility Violation

**Problem**:
Despite refactoring to extract `SessionHistoryService` and `QueueManager`, `SessionService` still violates Single Responsibility Principle by being a facade, state manager, and coordinator all at once.

**Evidence** (SessionService.swift):
- **Lines 20-21**: Creates sub-services (Factory responsibility)
- **Lines 24-27**: Manages state (State Manager responsibility)
- **Lines 29-48**: Exposes delegated properties (Facade responsibility)
- **Lines 58-67**: Manages turn logic (Coordinator responsibility)
- **Lines 77-116**: Orchestrates queue→history transitions (Orchestration responsibility)

**Specific Issues**:

**1. Turn Management Logic in Wrong Place**
```swift
// SessionService.swift:60-67
func addSongToHistory(...) {
    _ = historyService.addToHistory(...)

    // Turn management mixed with history management
    let newTurn = selectedBy == .user ? TurnType.ai : TurnType.user
    currentTurn = newTurn
}
```

Turn management should be in `TurnManager`, not `SessionService`.

**2. Complex State Transitions**
```swift
// SessionService.swift:96-107 - 42 lines of complex logic
func updateCurrentlyPlayingSong(songId: String) {
    // Check history first (buggy UUID check)
    if let _ = historyService.getSong(withId: UUID()) { ... }

    // Then check queue and move to history
    for sessionSong in queueManager.songQueue {
        if sessionSong.song.id.rawValue == songId {
            // Move song, update turn, manage state...
            // 20 lines of orchestration
        }
    }

    // Fallback behavior
    historyService.updateCurrentlyPlayingSong(songId: songId)
}
```

This single method:
- Iterates through queue manually
- Calls 4 different sub-service methods
- Has duplicated turn logic
- Has 3 different code paths

**3. Inconsistent Responsibilities**

Compare these two methods:
```swift
// Direct delegation (good)
func hasSongBeenPlayed(artist: String, title: String) -> Bool {
    historyService.hasSongBeenPlayed(artist: artist, title: title)
}

// Complex orchestration (bad)
func updateCurrentlyPlayingSong(songId: String) {
    // 42 lines of logic orchestrating multiple services
}
```

Some methods are simple delegations, others are complex orchestrations. Inconsistent responsibility level.

**Recommended Solution**:

**Separate concerns into distinct objects**:
```swift
// SessionFacade - Simple delegation only
final class SessionFacade {
    private let state: SessionState
    private let turnManager: TurnManager
    private let historyManager: SessionHistoryManager

    // Simple delegation
    var currentTurn: TurnType { turnManager.currentTurn }
    var sessionHistory: [SessionSong] { historyManager.history }
}

// PlaybackOrchestrator - Complex workflows
final class PlaybackOrchestrator {
    func handleSongTransition(from oldSong: Song?, to newSong: Song) async {
        // Complex logic coordinating multiple services
    }
}

// TurnManager - Turn logic only
final class TurnManager {
    func advanceTurn(after song: SessionSong) -> TurnType { ... }
}
```

---

### 2.3 Direction Change Feature Complexity
**Severity**: High
**Impact**: Maintainability, Code Clarity

**Problem**:
The direction change feature (PR #38) adds significant complexity with multiple moving parts:
- `DirectionChange` + `DirectionOption` models
- Caching in `SessionViewModel` (`cachedDirectionChange`, `lastDirectionGenerationSongId`)
- Generation in `SongSelectionService.generateDirectionChange()`
- Task management in `SessionViewModel.generateDirectionChange()` (fire-and-forget)
- User interaction in `SessionViewModel.handleDirectionChange()`
- UI presentation in `SessionActionButtons`

**Evidence** (SessionViewModel.swift:134-234):
100 lines dedicated to direction change feature, including:
- State management (lines 31-33)
- Generation logic (lines 138-191)
- User interaction (lines 195-227)
- Cache management (lines 230-234)

**Complexity Indicators**:
1. **Caching Logic**: Must track which song the direction was generated for
2. **Race Conditions**: Must cancel old prefetch tasks before starting new ones
3. **State Explosion**: `isGeneratingDirection`, `cachedDirectionChange`, `lastDirectionGenerationSongId`
4. **Turn Logic Confusion**: "Turn remains on user since they didn't select a song themselves"

**Why This Is Complex**:
The feature conflates three concerns:
- **AI prompt engineering**: Generating contextual suggestions
- **Caching**: Avoiding redundant AI calls
- **Task coordination**: Managing async generation without blocking UI

**Recommended Solution**:

Extract to dedicated feature module:
```swift
// DirectionChangeFeature.swift
@MainActor
@Observable
final class DirectionChangeFeature {
    private let aiService: AIRecommendationServiceProtocol
    private let sessionHistory: () -> [SessionSong]

    private(set) var cachedOptions: DirectionChange?
    private(set) var isGenerating = false
    private var cacheKey: String?  // Hash of session state

    func generateOptions() async {
        guard !isGenerating else { return }

        let currentKey = computeCacheKey()
        guard currentKey != cacheKey else { return }

        isGenerating = true
        defer { isGenerating = false }

        do {
            cachedOptions = try await aiService.generateDirectionChange(...)
            cacheKey = currentKey
        } catch {
            // Handle error
        }
    }

    private func computeCacheKey() -> String {
        // Hash of session history to detect when regeneration needed
    }
}
```

---

### 2.4 Duplicate Turn Logic
**Severity**: Medium
**Impact**: Maintainability, DRY Violation

**Problem**:
Turn advancement logic is duplicated in 3 places:

**Location 1** - SessionService.swift:96-107 (updateCurrentlyPlayingSong)
```swift
if removedSong.queueStatus == .upNext {
    let newTurn = removedSong.selectedBy == .user ? TurnType.ai : TurnType.user
    currentTurn = newTurn
} else if removedSong.queueStatus == .queuedIfUserSkips {
    currentTurn = .user
}
```

**Location 2** - SessionService.swift:145-155 (moveQueuedSongToHistory)
```swift
// Exact same logic duplicated
if song.queueStatus == .upNext {
    let newTurn = song.selectedBy == .user ? TurnType.ai : TurnType.user
    currentTurn = newTurn
} else if song.queueStatus == .queuedIfUserSkips {
    currentTurn = .user
}
```

**Location 3** - TurnManager.swift:81-92 (determineNextQueueStatus)
```swift
func determineNextQueueStatus() -> QueueStatus {
    if sessionService.currentTurn == .user {
        return .queuedIfUserSkips
    } else {
        return .upNext
    }
}
```

**Why This Is Problematic**:
1. **Logic drift**: If turn rules change, must update 3 places
2. **Bugs**: Easy to update one but forget others
3. **Testability**: Must test same logic 3 times
4. **TurnManager underutilized**: Has a method for queue status but not for turn advancement

**Recommended Solution**:

Consolidate in TurnManager:
```swift
// TurnManager.swift
enum TurnTransition {
    case switchTurn(to: TurnType)
    case keepCurrentTurn
}

func evaluateTurnTransition(
    after song: SessionSong,
    currentTurn: TurnType
) -> TurnTransition {
    switch song.queueStatus {
    case .upNext:
        let nextTurn = song.selectedBy == .user ? TurnType.ai : TurnType.user
        return .switchTurn(to: nextTurn)

    case .queuedIfUserSkips:
        return .keepCurrentTurn  // AI backup, user's turn continues

    case .playing, .played:
        return .keepCurrentTurn  // Already transitioned
    }
}
```

Then SessionService just calls:
```swift
func updateCurrentlyPlayingSong(songId: String) {
    // ... song transition logic ...
    let transition = turnManager.evaluateTurnTransition(after: song, currentTurn: currentTurn)
    switch transition {
    case .switchTurn(let newTurn):
        currentTurn = newTurn
    case .keepCurrentTurn:
        break
    }
}
```

---

### 2.5 ViewModelError Protocol Unused
**Severity**: Medium
**Impact**: Architecture Consistency

**Problem**:
`ViewModelError` protocol (70 lines) defines unified error handling pattern with comprehensive logging, but **NO ViewModels actually adopt it**.

**Evidence**:
```bash
$ grep -r "ViewModelError" Back2Back/
ViewModels/ViewModelError.swift: protocol ViewModelError
```

Only the protocol definition exists. No conformances.

**Why This Matters**:
1. **Dead code**: 70 lines of protocol + extensions unused
2. **Inconsistent error handling**: Each ViewModel does it differently
3. **Lost opportunity**: Good pattern that could improve UX

**Check ViewModels**:
- `SessionViewModel` - No error handling
- `NowPlayingViewModel` - Logs errors directly
- `MusicSearchViewModel` - Not examined
- `PersonasViewModel` - Not examined

**Recommended Solution**:

**Option A**: Delete the protocol if not using it

**Option B**: Actually use it:
```swift
@MainActor
@Observable
final class SessionViewModel: ViewModelError {
    var errorMessage: String?  // Required by protocol

    func handleUserSongSelection(_ song: Song) async {
        do {
            // ... work ...
        } catch {
            handleError(error, context: "Failed to select song")
        }
    }
}
```

---

## 3. Minor Issues

### 3.1 Mutable SessionSong Struct
**Severity**: Low
**Impact**: Unexpected Mutation, Value Semantics Violation

**Problem**:
`SessionSong` is a struct (value type) but has `var queueStatus` which gets mutated throughout the codebase.

**Evidence** (SessionService.swift:198-205):
```swift
struct SessionSong: Identifiable {
    let id: UUID
    let song: Song
    let selectedBy: TurnType
    let timestamp: Date
    let rationale: String?
    var queueStatus: QueueStatus  // Mutable!
}
```

**Usage** (QueueManager.swift:82-85):
```swift
func updateSongStatus(id: UUID, newStatus: QueueStatus) {
    if let index = songQueue.firstIndex(where: { $0.id == id }) {
        songQueue[index].queueStatus = newStatus  // Mutating struct in array
    }
}
```

**Why This Is Awkward**:
1. **Value semantics violation**: Structs should be immutable
2. **Mutation complexity**: Must find index and mutate in place
3. **State confusion**: Is `queueStatus` part of identity or mutable state?

**Recommended Solution**:

**Option A**: Make it a class (if frequent mutation)
```swift
final class SessionSong: Identifiable { ... }
```

**Option B**: Make it fully immutable (if rare mutation)
```swift
struct SessionSong: Identifiable {
    let id: UUID
    let song: Song
    let selectedBy: TurnType
    let timestamp: Date
    let rationale: String?
    let queueStatus: QueueStatus  // let, not var
}

// Create new instances instead of mutating
func updateSongStatus(id: UUID, newStatus: QueueStatus) {
    if let index = songQueue.firstIndex(where: { $0.id == id }) {
        let old = songQueue[index]
        songQueue[index] = SessionSong(
            id: old.id,
            song: old.song,
            selectedBy: old.selectedBy,
            timestamp: old.timestamp,
            rationale: old.rationale,
            queueStatus: newStatus
        )
    }
}
```

---

### 3.2 SessionViewModel.shared Singleton Smell
**Severity**: Low
**Impact**: Testability, Multiple Instances Not Possible

**Problem**:
`SessionViewModel` is a singleton (`static let shared`), which is unusual for ViewModels. ViewModels are typically instantiated per view.

**Evidence** (SessionViewModel.swift:18):
```swift
@MainActor
@Observable
final class SessionViewModel {
    static let shared = SessionViewModel()
```

**Why This Is Odd**:
1. **Single global session**: Can't have multiple session views
2. **Testing complexity**: Can't create fresh ViewModels for tests
3. **State leaks**: Previous test state affects next test
4. **Not SwiftUI idiomatic**: Views typically own their ViewModels via `@StateObject`

**Current Usage** (SessionView.swift:14):
```swift
struct SessionView: View {
    private let sessionViewModel = SessionViewModel.shared  // Shared across all instances
```

**Recommended Solution**:

Remove singleton, make it instance-based:
```swift
// SessionViewModel.swift
@MainActor
@Observable
final class SessionViewModel {
    // Remove: static let shared = SessionViewModel()

    private let musicService: MusicServiceProtocol
    // ... other dependencies ...

    init(
        musicService: MusicServiceProtocol,
        sessionService: SessionStateManagerProtocol,
        // ... explicit dependencies ...
    ) {
        self.musicService = musicService
        self.sessionService = sessionService
    }
}

// SessionView.swift
struct SessionView: View {
    @State private var viewModel: SessionViewModel

    init(viewModel: SessionViewModel = .createDefault()) {
        self.viewModel = viewModel
    }

    // Or use Environment
    @Environment(\.sessionViewModel) private var viewModel
}
```

---

### 3.3 Status Message Service Coupling
**Severity**: Low
**Impact**: Unexpected Side Effect

**Problem**:
`PersonaService.selectPersona()` has side effect of triggering status message pregeneration.

**Evidence** (PersonaService.swift:136-138):
```swift
func selectPersona(_ persona: Persona) {
    // ... selection logic ...

    // Pregenerate status messages for the newly selected persona
    StatusMessageService.shared.pregenerateMessages(for: persona)
}
```

**Why This Is Unexpected**:
1. **Hidden behavior**: Method name doesn't indicate AI generation starts
2. **Performance impact**: Selecting persona triggers background AI work
3. **Coupling**: PersonaService → StatusMessageService
4. **Testing surprise**: Tests of `selectPersona()` start async AI generation

**Recommended Solution**:

Extract to coordinator or make explicit:
```swift
// PersonaService - just manages persona state
func selectPersona(_ persona: Persona) {
    // ... selection logic only ...
}

// AppCoordinator or PersonaCoordinator
func userSelectedPersona(_ persona: Persona) {
    personaService.selectPersona(persona)

    // Explicitly pregenerate
    statusMessageService.pregenerateMessages(for: persona)
}
```

---

### 3.4 Fire-and-Forget Task Pattern Overuse
**Severity**: Low
**Impact**: Error Handling, Resource Tracking

**Problem**:
Multiple services use fire-and-forget task patterns (`Task.detached { ... }`) which makes error handling and lifecycle management difficult.

**Examples**:

**1. StatusMessageService** (StatusMessageService.swift:111):
```swift
private func generateMessages(for persona: Persona) {
    Task.detached { @MainActor [weak self] in
        // ... generation logic ...
        // Errors logged but not propagated
    }
}
```

**2. SessionViewModel** (SessionViewModel.swift:140):
```swift
func generateDirectionChange() {
    Task.detached { @MainActor [weak self] in
        // ... generation logic ...
        // No way to know if it completed or failed
    }
}
```

**3. AISongCoordinator** (AISongCoordinator.swift:236):
```swift
prefetchTask = Task.detached { [weak self] in
    await self?.prefetchAndQueueAISong(...)
}
```

**Why This Is Concerning**:
1. **Lost errors**: Exceptions are swallowed, only logged
2. **No cancellation tracking**: Can't tell if still running
3. **Resource leaks**: Tasks may outlive their owner
4. **Testing difficulty**: Can't await completion

**Recommended Solution**:

Track tasks and provide awaitable completion:
```swift
final class StatusMessageService {
    private var generationTask: Task<StatusMessages, Error>?

    func generateMessages(for persona: Persona) async throws -> StatusMessages {
        // Cancel existing
        generationTask?.cancel()

        // Create tracked task
        generationTask = Task {
            let model = SystemLanguageModel()
            return try await model.generate(...)
        }

        return try await generationTask!.value
    }
}
```

---

### 3.5 QueueStatus Enum Should Be CaseIterable
**Severity**: Low
**Impact**: Code Convenience

**Problem**:
`QueueStatus` enum has `displayText` and `description` but isn't `CaseIterable`, making it harder to iterate or test all cases.

**Evidence** (MusicModels.swift:55-86):
```swift
enum QueueStatus: CustomStringConvertible {
    case playing
    case upNext
    case queuedIfUserSkips
    case played

    var displayText: String { ... }
    var description: String { ... }
}
```

**Recommended Solution**:
```swift
enum QueueStatus: CaseIterable, CustomStringConvertible {
    // ... cases ...
}

// Now can iterate
for status in QueueStatus.allCases {
    print(status.displayText)
}
```

---

## 4. Testing Architecture Issues

### 4.1 Mock Services Only Used in Tests
**Severity**: Medium
**Impact**: Test Isolation, Protocol Usage

**Problem**:
Three mock implementations exist (`MockMusicService`, `MockAIRecommendationService`, `MockSessionStateManager`) but they're **only used by test code**. Production code always uses real singletons.

**Evidence**:
```bash
$ find . -name "Mock*.swift"
./Back2BackTests/Mocks/MockMusicService.swift
./Back2BackTests/Mocks/MockAIRecommendationService.swift
./Back2BackTests/Mocks/MockSessionStateManager.swift
```

**Why This Matters**:
1. **Protocols pointless in production**: Only used for mocking
2. **Tests don't reflect reality**: Use dependency injection while production doesn't
3. **False confidence**: Tests pass with mocks but production may fail

**Example** (MockMusicService.swift):
```swift
@MainActor
final class MockMusicService: MusicServiceProtocol {
    // Full implementation for testing
}
```

But `SessionViewModel` in production:
```swift
private let musicService: MusicService  // Concrete type, not protocol
```

**Recommended Solution**:

**Option A**: Use protocols in production (with DI container)
**Option B**: Delete protocols and use concrete mocks

```swift
// Concrete mock without protocol
final class MockMusicService: MusicService {
    override func playSong(_ song: Song) async throws {
        // Override behavior
    }
}
```

---

### 4.2 SessionViewModelTests Mostly Commented Out
**Severity**: Medium
**Impact**: Test Coverage

**Problem**:
`SessionViewModelTests.swift` has **336 lines** but lines 29-64 are commented out because "Song is a MusicKit type that cannot be instantiated in tests".

**Evidence** (SessionViewModelTests.swift:26-64):
```swift
// Note: Tests that require creating Song instances are commented out
// as Song is a MusicKit type that cannot be instantiated in tests

/*
@MainActor
@Test("Find best match - exact match")
func testFindBestMatchExact() {
    // This test requires creating Song instances which is not possible
}
*/
```

**Why This Is Problematic**:
1. **Low coverage**: Core matching logic untested
2. **Commented code smell**: Should delete or fix, not comment
3. **Workaround available**: Can create wrapper types or use real API in tests

**Recommended Solution**:

**Option A**: Wrapper types for testing
```swift
protocol SongRepresentable {
    var id: String { get }
    var title: String { get }
    var artistName: String { get }
}

extension Song: SongRepresentable { }

struct MockSong: SongRepresentable {
    let id: String
    let title: String
    let artistName: String
}

// Test with MockSong
```

**Option B**: Integration tests with real MusicKit
```swift
@Test("Find best match with real MusicKit", .tags(.integration))
func testFindBestMatchIntegration() async throws {
    let results = try await MusicService.shared.searchCatalog(for: "Beatles Hey Jude")
    // Test with real Song objects
}
```

---

### 4.3 AIRetryStrategyTests Not Found
**Severity**: Low
**Impact**: Test Coverage

**Problem**:
`AIRetryStrategyTests.swift` exists but wasn't examined. Given the complexity of the retry logic and the task cancellation issues, this file should have comprehensive tests.

**Evidence**:
```bash
$ find . -name "AIRetryStrategyTests.swift"
./Back2BackTests/AIRetryStrategyTests.swift
```

**Recommended Review**:
- Does it test cancellation handling?
- Does it test the nil return case?
- Does it test retry count limits?
- Does it test error propagation?

---

## 5. SwiftUI Architecture

### 5.1 @Observable Used Correctly
**Severity**: None (Positive)
**Impact**: Modern SwiftUI patterns

**Positive Pattern**:
The codebase correctly uses iOS 17+ `@Observable` macro instead of legacy `ObservableObject`. This provides better performance and cleaner syntax.

**Evidence** (SessionViewModel.swift:17):
```swift
@MainActor
@Observable
final class SessionViewModel {
    // Properties automatically tracked
}
```

**Benefits**:
- No need for `@Published` wrappers
- Better compilation times
- Cleaner property syntax

---

### 5.2 View Composition Generally Good
**Severity**: None (Positive)
**Impact**: Code Organization

**Positive Pattern**:
Views are well-decomposed into subviews:
- `SessionView` → `SessionHeaderView`, `SessionHistoryListView`, `SessionActionButtons`
- Clear separation of concerns at view level

**Evidence** (SessionView.swift:19-33):
```swift
VStack {
    SessionHeaderView(onNowPlayingTapped: { showNowPlaying = true })
    SessionHistoryListView()
    SessionActionButtons(...)
}
```

---

### 5.3 Toast Service is Well-Designed
**Severity**: None (Positive)
**Impact**: User Experience

**Positive Pattern**:
`ToastService` shows good design:
- Queue management for multiple toasts
- Auto-dismiss with Task cancellation
- Convenience methods (`.error()`, `.success()`)
- Clean API

**Evidence** (ToastService.swift:38-63):
```swift
func show(_ message: String, type: ToastType = .error, duration: TimeInterval = 4.0) {
    let toast = Toast(...)
    if currentToast == nil {
        presentToast(toast)
    } else {
        toastQueue.append(toast)
    }
}
```

This is a **model for other services** to follow.

---

### 5.4 NowPlayingViewModel Animation-Based Tracking
**Severity**: None (Positive)
**Impact**: Performance

**Positive Pattern**:
`NowPlayingViewModel` uses animation-based progress tracking instead of polling timers.

**Evidence** (NowPlayingViewModel.swift:18-57):
```swift
// Instead of polling every 500ms, we track a base time and calculate elapsed
var basePlaybackTime: TimeInterval = 0
var animationStartTime: Date?

func getCurrentPlaybackTime() -> TimeInterval {
    guard isPlaying, let startTime = animationStartTime else {
        return basePlaybackTime
    }
    let elapsed = Date().timeIntervalSince(startTime)
    return basePlaybackTime + elapsed
}
```

**Benefits**:
- No timer overhead
- Smooth 60fps progress bars
- Less CPU usage

This follows Apple's recommendation for MusicKit playback tracking.

---

## 6. Code Quality & Design Patterns

### 6.1 Facade Pattern Well-Implemented
**Severity**: None (Positive)
**Impact**: API Simplification

**Positive Pattern**:
`MusicService` acts as a clean facade over complex MusicKit subsystems.

**Evidence** (MusicService.swift:17-124):
```swift
@MainActor
@Observable
class MusicService: MusicServiceProtocol {
    // Delegates to specialized services
    private let authService = MusicAuthService()
    private let searchService = MusicSearchService()
    private let playbackService = MusicPlaybackService()

    // Simple delegation
    func playSong(_ song: Song) async throws {
        try await playbackService.playSong(song)
    }
}
```

**Benefits**:
- Clean client-facing API
- Internal complexity hidden
- Easy to swap implementations

---

### 6.2 B2BLog Logging System Excellent
**Severity**: None (Positive)
**Impact**: Debugging, Production Monitoring

**Positive Pattern**:
Comprehensive logging system with subsystems, log levels, and convenience methods.

**Evidence** (Usage throughout codebase):
```swift
B2BLog.session.info("User selected: \(song.title)")
B2BLog.ai.debug("AI thinking state: \(thinking)")
B2BLog.playback.error("Failed to play song: \(error)")
```

**Benefits**:
- Consistent logging style
- Easy filtering by subsystem
- Performance tracking built-in

This is **production-quality infrastructure**.

---

### 6.3 String Normalization is Thorough
**Severity**: None (Positive)
**Impact**: Matching Quality

**Positive Pattern**:
`StringBasedMusicMatcher` has comprehensive string normalization handling:
- Unicode apostrophes (U+2019 → ')
- Diacritics (é → e)
- Featuring artists (feat., ft., featuring)
- "The" prefix removal
- Ampersand normalization (& → and)
- Parenthetical stripping
- Part number removal

**Evidence** (StringBasedMusicMatcher.swift:162-202):
```swift
private func normalizeString(_ string: String) -> String {
    // 40 lines of careful normalization
}
```

This shows **attention to edge cases** and real-world data quality issues.

---

## 7. Recommendations Summary

### Priority 1 (Critical - Address First)

1. **Eliminate Singleton Dependency Hell**
   - Implement dependency injection container or Environment-based injection
   - Make all service dependencies explicit through constructors
   - Timeline: 2-3 weeks, affects entire codebase
   - Benefit: Testability, maintainability, clear dependency graph

2. **Fix Task Cancellation Race Conditions**
   - Actually cancel tasks instead of invalidating IDs
   - Fix AIRetryStrategy to handle cancellation properly
   - Use structured concurrency patterns
   - Timeline: 1 week
   - Benefit: Resource efficiency, correctness, fewer bugs

3. **Consolidate Session State Management**
   - Create single source of truth for session state
   - Remove state split across 5 services
   - Fix UUID bug in `updateCurrentlyPlayingSong()`
   - Timeline: 2 weeks
   - Benefit: Correctness, reduced complexity, fewer sync bugs

### Priority 2 (High - Address Soon)

4. **Resolve Protocol Usage Inconsistency**
   - Either use protocols throughout or delete them
   - Make dependency injection work with @Observable
   - Timeline: 1 week
   - Benefit: Architecture integrity, testability

5. **Refactor SessionService God Object**
   - Split into Facade, State Manager, and Orchestrator
   - Move turn logic to TurnManager
   - Timeline: 1-2 weeks
   - Benefit: Single responsibility, easier testing

6. **Extract Direction Change Feature**
   - Create dedicated feature module
   - Reduce SessionViewModel complexity
   - Timeline: 3-4 days
   - Benefit: Maintainability, reusability

### Priority 3 (Medium - Nice to Have)

7. **Consolidate Turn Logic**
   - Move all turn advancement to TurnManager
   - Remove duplication from SessionService
   - Timeline: 2-3 days
   - Benefit: DRY principle, single source of truth

8. **Improve Test Coverage**
   - Uncomment or rewrite SessionViewModelTests
   - Use wrapper types for MusicKit objects
   - Add integration tests
   - Timeline: 1 week
   - Benefit: Confidence, regression prevention

9. **Standardize Error Handling**
   - Either adopt ViewModelError or delete it
   - Consistent error handling across ViewModels
   - Timeline: 2-3 days
   - Benefit: Consistency, better UX

### Priority 4 (Low - Future Improvements)

10. **Clean Up Fire-and-Forget Tasks**
    - Make tasks trackable and awaitable
    - Better error propagation
    - Timeline: 1 week
    - Benefit: Debugging, resource management

11. **Small Fixes**
    - Make SessionSong immutable
    - Remove SessionViewModel singleton
    - Add CaseIterable to QueueStatus
    - Timeline: 1 day
    - Benefit: Code quality

---

## 8. Positive Patterns to Maintain

1. **Logging System** (B2BLog) - Keep this approach
2. **Toast Service** - Use as template for other services
3. **String Normalization** - Thorough edge case handling
4. **@Observable Usage** - Modern SwiftUI patterns
5. **View Composition** - Good decomposition
6. **Animation-Based Tracking** - Efficient progress monitoring
7. **Facade Pattern** - MusicService shows good API design
8. **Protocol-Oriented Matching** - MusicMatchingProtocol is well-designed

---

## 9. Architecture Evolution Recommendations

### Short Term (Next 3 months)
- Fix critical singleton issues
- Resolve task cancellation bugs
- Consolidate session state

### Medium Term (3-6 months)
- Implement proper dependency injection
- Refactor service layer
- Improve test coverage to 80%+

### Long Term (6-12 months)
- Consider modular architecture (Swift Packages)
- Extract features into separate modules
- Implement TCA or similar unidirectional data flow

---

## 10. Conclusion

The Back2Back app has **solid foundations** with clear service separation, modern SwiftUI patterns, and thoughtful features. The architecture has improved significantly through recent refactoring efforts.

However, **singleton proliferation** and **state synchronization complexity** are accumulating technical debt. As the app grows, these issues will compound, making changes riskier and testing harder.

**Key Takeaway**: The team understands good architecture principles (protocols, separation of concerns, coordinators) but is constrained by SwiftUI's @Observable requirements and rapid feature development. The recommended solution is to invest 4-6 weeks in resolving the dependency injection and state management issues before adding major new features.

**Overall Grade**: **B+** (Good foundation, clear improvement path)

---

**Review Completed**: October 13, 2025
**Next Review Recommended**: After implementing Priority 1 recommendations (3 months)
