# Copilot Instructions for Better (Gemini iOS Client)

## Architecture Overview

This is a Swift 6 / SwiftUI iOS app that provides an advanced Gemini AI chat client with branching conversations. Key architectural decisions:

- **Direct Gemini REST API** - Uses custom networking layer against `generativelanguage.googleapis.com/v1beta/` rather than Firebase AI Logic SDK (see [PLAN.md](../PLAN.md) for rationale: full API feature access)
- **Firebase backend** - Auth (Google Sign-In), Firestore (persistence), Storage (media)
- **Branching message tree** - Messages have `parentId` references enabling conversation forking/regeneration

## Project Structure

```
better/
├── App/           # App entry point and global state
├── Models/        # Codable data models (Conversation, Message)
├── Services/      # API clients, Firebase, Keychain
├── ViewModels/    # @Observable ViewModels with @MainActor
├── Views/         # SwiftUI views organized by feature
└── Utilities/     # Constants, Theme, Haptics
```

## Key Patterns

### ViewModels
- Use `@Observable` macro with `@MainActor` annotation
- Use `final class` for all ViewModels and Services
- Firebase listeners stored with `nonisolated(unsafe)` for cleanup in deinit:
```swift
@MainActor @Observable
final class ChatViewModel {
    nonisolated(unsafe) private var messagesListener: ListenerRegistration?
}
```

### Message Tree (Branching)
Messages form a tree via `parentId`. The active branch is computed by walking children and selecting by `selectedAt` date:
```swift
// ChatViewModel.activeBranch builds the current conversation path
// siblings(of:) returns alternate branches at any node
// switchBranch(for:direction:) navigates between siblings
```

### Streaming Responses
[GeminiStreamParser.swift](../better/Services/GeminiStreamParser.swift) parses SSE streams into `StreamEvent` enum variants:
- `.text(String)` - Regular response text
- `.thinking(String)` - Model's thinking content (for thinking models)
- `.imageData(Data, mimeType)` - Inline generated images
- `.functionCall(name, args)` - Tool calls (image/video generation)
- `.usageMetadata(inputTokens, outputTokens, cachedTokens)` - Token counts

### Firebase Data Structure
```
users/{userId}/
  conversations/{conversationId}/
    messages/{messageId}
```
See [firestore.rules](../firestore.rules) - users can only access their own data.

### Theme System
[Theme.swift](../better/Utilities/Theme.swift) defines the PostrBoard-inspired color palette with semantic colors (`Theme.peach`, `Theme.mint`, `Theme.lavender`) and gradients. Use these instead of raw colors:
```swift
.foregroundStyle(Theme.charcoal)
.background(Theme.userBubbleGradient)
.gradientIcon()  // View modifier for accent gradient on icons
.adaptiveBackground()  // View modifier for light/dark backgrounds
```

## Conventions

### Models
- All models are `Codable`, `Identifiable`, `Equatable`, `Hashable`
- Use `var` properties for Firestore serialization
- IDs default to `UUID().uuidString`

### API Client
[GeminiAPIClient.swift](../better/Services/GeminiAPIClient.swift) patterns:
- Async/await for all requests
- `GenerationConfig` struct for model parameters (temperature, topP, topK, maxOutputTokens, thinkingBudget)
- `ToolsConfig` for enabling Google Search, code execution, URL context, image/video generation
- Returns `AsyncStream<StreamEvent>` for streaming

### Error Handling
- Use `GeminiAPIError` enum for API errors with `LocalizedError` conformance
- ViewModels expose `errorMessage: String?` for UI display

### Constants
[Constants.swift](../better/Utilities/Constants.swift) contains:
- Model names: `Constants.Models.flash`, `.pro`, `.flashImage`, `.proImage`
- Default parameters: `Constants.Defaults.temperature`, etc.
- Firestore collection names: `Constants.Firestore.usersCollection`, etc.

## Build & Run

Open `better.xcodeproj` in Xcode. Requires:
- Xcode 16+ (Swift 6)
- iOS 18+ deployment target
- Firebase configuration in `GoogleService-Info.plist`
- User must provide their own Gemini API key (stored in Keychain)

## Adding New Features

1. **New API capability**: Add to `GeminiAPIClient`, update `ToolsConfig` if tool-based
2. **New conversation setting**: Add property to `Conversation` model, update `ParameterControlsView`
3. **New message type**: Extend `StreamEvent` enum and `GeminiStreamParser`, handle in `ChatViewModel.startStreamingResponse`
4. **New view**: Create in appropriate `Views/` subfolder, follow existing patterns for state management
