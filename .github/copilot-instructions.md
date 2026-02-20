# Copilot Instructions for Better (OpenRouter iOS Client)

## Architecture Overview

This is a Swift 6 / SwiftUI iOS app that provides an AI chat client with branching conversations, powered by OpenRouter API via a Firebase Functions v2 proxy. Key architectural decisions:

- **Firebase Functions v2 proxy** — All OpenRouter API calls go through a Cloud Run-based Firebase Function that verifies Firebase Auth and injects the API key server-side. The OpenRouter API key never touches the client.
- **Firebase backend** — Auth (Google Sign-In), Firestore (persistence + user settings), Storage (media)
- **Branching message tree** — Messages have `parentId` references enabling conversation forking/regeneration

## Project Structure

```
better/
├── App/           # App entry point and global state
├── Models/        # Codable data models (Conversation, Message)
├── Services/      # API clients, Firebase services
├── ViewModels/    # @Observable ViewModels with @MainActor
├── Views/         # SwiftUI views organized by feature
└── Utilities/     # Constants, Theme, Haptics

functions/         # Firebase Functions v2 (TypeScript)
└── src/index.ts   # SSE proxy function
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

### API Proxy Architecture
- **No client-side API key** — The OpenRouter API key lives only in Firebase Secret Manager
- **Auth flow**: iOS app gets Firebase Auth ID token → sends as Bearer token → Firebase Function verifies it → forwards request to OpenRouter with server-side API key
- **SSE streaming**: The proxy function pipes OpenRouter's SSE stream directly back to the iOS client. The `OpenRouterStreamParser` is unchanged.
- **Endpoint routing**: Client sends `X-OpenRouter-Path` header to specify which OpenRouter sub-endpoint to call (e.g., `chat/completions`, `jobs/{id}`)
- **Proxy URL**: Set in `Constants.apiProxyBaseURL` — update after deployment

### Custom Instructions
- Stored in Firestore at `users/{userId}` document under `customInstructions` field
- Loaded by `ChatViewModel` on init and by `SettingsView` on appear
- Saved via explicit "Save" button in Settings
- Sent as part of the system instruction in every API call

### Media Attachments
[MediaService.swift](../better/Services/MediaService.swift) and [MediaTypes.swift](../better/Utilities/MediaTypes.swift) handle file uploads:
- **Supported formats**: Images (PNG, JPEG, WEBP, HEIC, HEIF), PDFs
- **Size limits**: 15MB for images, 10MB for PDFs (conservative for base64 encoding)
- **Upload flow**: User selects → validate → upload to Firebase Storage → store URL in Message
- **Send flow**: Download media bytes from Storage URLs → send as inline data via proxy to OpenRouter API
- **Caching**: MediaService maintains in-memory cache to avoid re-downloading on regenerate
- **Picker implementation**: Image attachments use `PHPickerViewController` (`PhotoAttachmentPicker`) with NSItemProvider `loadFileRepresentation/loadDataRepresentation` instead of CoreTransferable wrappers for better reliability.

### Firebase Data Structure
```
users/{userId}/
  customInstructions: String        # User's custom system instructions
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
- Uses Firebase Auth ID token (via `Auth.auth().currentUser?.getIDToken()`) for proxy authentication
- `GenerationConfig` struct for model parameters (temperature, topP, topK, maxOutputTokens)
- Returns `AsyncStream<StreamEvent>` for streaming
- `MessagePayload` with `mediaData`/`mediaMimeType` for attaching images and PDFs
- Uses OpenAI-compatible request format sent through Firebase proxy

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
- `Constants.apiProxyBaseURL` — Firebase Functions v2 proxy endpoint
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

## Settings
The app has a single settings screen with:
- **Account**: Profile info (name, email) and Sign Out
- **Custom Instructions**: Free-text editor for user-defined system instructions, persisted to Firestore

There is no API key management UI — the API key is managed server-side.

## Build & Run

Open `better.xcodeproj` in Xcode. Requires:
- Xcode 16+ (Swift 6)
- iOS 26+ deployment target
- Firebase configuration in `GoogleService-Info.plist`
- Users sign in with Google — no API key needed

### Firebase Functions
```bash
cd functions && npm install && npm run build
firebase deploy --only functions
firebase functions:secrets:set OPENROUTER_API_KEY  # Set the API key
```

## Adding New Features

1. **New model**: Add to `Constants.Models` and `allTextModels` array
2. **New message type**: Extend `StreamEvent` enum, handle in `ChatViewModel.startStreamingResponse`
3. **New view**: Create in appropriate `Views/` subfolder, follow existing patterns for state management
4. **New proxy endpoint**: Add path to `ALLOWED_PATHS` in `functions/src/index.ts`

## Image & Video Generation

- **Images**: Use `ImageGenerationService` with Seedream 4.5 ($0.04/image)
- **Videos**: Use `VideoGenerationService` with Seedance 2.0 (async job-based, $0.10-$0.80/min)
