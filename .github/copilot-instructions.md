# Copilot Instructions for Better (OpenRouter iOS Client)

## Architecture Overview

This is a Swift 6 / SwiftUI iOS app that provides an AI chat client with branching conversations, powered by OpenRouter API. Key architectural decisions:

- **OpenRouter API** - Uses unified API gateway at `openrouter.ai/api/v1/` providing access to multiple AI models (DeepSeek V3.2, DeepSeek R1, etc.)
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
OpenRouterAPIClient uses OpenAI-compatible SSE format, parsed into `StreamEvent` enum:
- `.text(String)` - Regular response text
- `.thinking(String)` - Model's reasoning/thinking content (DeepSeek R1). OpenRouter providers may use either `reasoning` or `reasoning_content` field name — the parser handles both.
- `.imageData(Data, mimeType)` - Inline generated images
- `.functionCall(name, args)` - Not used with OpenRouter
- `.usageMetadata(inputTokens, outputTokens, cachedTokens)` - Token counts

### Keychain & API Key Management
- API key stored in keychain under account `"openrouter-api-key"` with service `"com.postrboard.better"`
- Legacy migration: `loadAPIKey()` also checks for keys under the old `"gemini-api-key"` account and migrates automatically
- In DEBUG builds, the key can be injected via `OPEN_ROUTER_KEY` environment variable (for simulator testing with `SIMCTL_CHILD_OPEN_ROUTER_KEY`)

### Media Attachments
[MediaService.swift](../better/Services/MediaService.swift) and [MediaTypes.swift](../better/Utilities/MediaTypes.swift) handle file uploads:
- **Supported formats**: Images (PNG, JPEG, WEBP, HEIC, HEIF), PDFs
- **Size limits**: 15MB for images, 10MB for PDFs (conservative for base64 encoding)
- **Upload flow**: User selects → validate → upload to Firebase Storage → store URL in Message
- **Send flow**: Download media bytes from Storage URLs → send as inline data to OpenRouter API
- **Caching**: MediaService maintains in-memory cache to avoid re-downloading on regenerate
- **Picker implementation**: Image attachments use `PHPickerViewController` (`PhotoAttachmentPicker`) with NSItemProvider `loadFileRepresentation/loadDataRepresentation` instead of CoreTransferable wrappers for better reliability.

### Firebase Data Structure
```
users/{userId}/
  conversations/{conversationId}/
    messages/{messageId}

media/{userId}/{conversationId}/{messageId}
  - Uploaded media files (images, PDFs)
```
See [firestore.rules](../firestore.rules) and [storage.rules](../storage.rules) - users can only access their own data.

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
[OpenRouterAPIClient.swift](../better/Services/OpenRouterAPIClient.swift) patterns:
- Async/await for all requests
- `GenerationConfig` struct for model parameters (temperature, topP, topK, maxOutputTokens)
- Returns `AsyncStream<StreamEvent>` for streaming
- `MessagePayload` with `mediaData`/`mediaMimeType` for attaching images and PDFs
- Uses OpenAI-compatible request format with Bearer auth

### Available Models
Defined in [Constants.swift](../better/Utilities/Constants.swift):
- **Text**: `Constants.Models.deepseekChat` (Fast), `.deepseekR1` (Thoughtful)
- **Vision (auto-routed when user messages have media attached)**: `Constants.Models.qwenVision` (`qwen/qwen2.5-vl-32b-instruct`)
- **Image**: `Constants.Models.seedream` (ByteDance Seedream 4.5)
- **Video**: `Constants.Models.seedance` (ByteDance Seedance 2.0)

### Error Handling
- Use `OpenRouterAPIError` enum for API errors with `LocalizedError` conformance
- `GeminiAPIError` is a typealias to `OpenRouterAPIError` for backward compatibility
- ViewModels expose `errorMessage: String?` for UI display

### Constants
[Constants.swift](../better/Utilities/Constants.swift) contains:
- Model names: `Constants.Models.deepseekChat`, `.deepseekR1`, `.qwenVision`, `.seedream`, `.seedance`
- Default parameters: `Constants.Defaults.temperature`, etc.
- Firestore collection names: `Constants.Firestore.usersCollection`, etc.

### Media Routing
- Vision model is auto-selected only when **user** messages have media — assistant-generated media (images/videos) is NOT sent back to the API
- `detectMediaIntent` keyword matching triggers image/video generation via dedicated services
- `regenerate` and `editAndResend` respect both intent detection and media attachment routing

### Attachment Notes
- DeepSeek text models are not vision-capable; attachment requests are routed to `qwenVision`.
- On iOS Simulator, iCloud-only assets can still fail (`CloudPhotoLibraryErrorDomain` / `PHAssetExportRequestErrorDomain`); keep a local photo available for deterministic attachment testing.

## Build & Run

Open `better.xcodeproj` in Xcode. Requires:
- Xcode 16+ (Swift 6)
- iOS 18+ deployment target
- Firebase configuration in `GoogleService-Info.plist`
- User must provide their own OpenRouter API key (stored in Keychain)

## Adding New Features

1. **New model**: Add to `Constants.Models` and `allTextModels` array
2. **New conversation setting**: Add property to `Conversation` model, update `ParameterControlsView`
3. **New message type**: Extend `StreamEvent` enum, handle in `ChatViewModel.startStreamingResponse`
4. **New view**: Create in appropriate `Views/` subfolder, follow existing patterns for state management

## Image & Video Generation

- **Images**: Use `ImageGenerationService` with Seedream 4.5 ($0.04/image)
- **Videos**: Use `VideoGenerationService` with Seedance 2.0 (async job-based, $0.10-$0.80/min)
