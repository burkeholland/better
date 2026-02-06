# "Better" — A Superior Gemini Client for iOS

## Current Gemini iOS App: Feature Audit

**What it does:**
- Text chat with Gemini models
- Voice input (speech-to-text)
- Camera/photo input for multimodal queries
- Image generation (via Imagen/Nano Banana)
- Google Search grounding ("Gemini with Google")
- Workspace extensions (Gmail, Drive, Docs, YouTube, Maps)
- Conversation history (synced to Google account)
- Gemini Live voice conversations
- Deep Research
- Multiple conversation threads
- Gemini Advanced tier (2.5 Pro, larger context)

## Its Gaps & Pain Points (what makes it terrible)

1. **No conversation editing** — can't go back to a previous message and regenerate from that point
2. **No rollback** — can't truncate a conversation at a specific message
3. **No model switching** — locked to whatever tier you're on, can't pick specific model versions
4. **No parameter control** — no temperature, top-p, top-k, max tokens, thinking budget
5. **No system instructions** — can't set custom persona/behavior per chat
6. **Poor code rendering** — no syntax highlighting, no copy button on code blocks
7. **No markdown quality** — mediocre rendering of tables, LaTeX, nested lists
8. **No export** — can't export conversations as JSON, markdown, or PDF
9. **No private/local chats** — everything goes to Google's servers with no local-only option
10. **No token counting** — no visibility into context usage
11. **No streaming control** — can't stop generation mid-stream cleanly
12. **No branching conversations** — no tree-based chat history
13. **No file attachments beyond images** — limited PDF/document support on mobile
14. **No TTS for responses** — can't have responses read aloud with Gemini voices
15. **No Nano Banana Pro** — the API supports 4K image gen with Gemini 3 Pro Image, the app doesn't expose full controls
16. **No Veo video generation** — API supports it, app doesn't
17. **No structured output mode** — can't request JSON schema responses
18. **No function calling control** — can't define custom tools
19. **No URL context** — can't ask it to read a specific webpage
20. **No haptic feedback, no swipe gestures, no power-user shortcuts**

---

## Architecture Decision: REST API Direct (not Firebase AI Logic)

The Firebase AI Logic SDK for Swift doesn't expose all API features (Deep Research via Interactions API, TTS, Veo, Lyria, full tool configuration). We'll build a **native Swift networking layer directly against the Gemini REST API**, giving us full control over every endpoint and parameter. This also eliminates the Firebase dependency.

---

## Build Plan — Phased Implementation

### Phase 1: Core Foundation
> Data models, networking layer, basic chat UI

| # | Work Unit | Details |
|---|-----------|---------|
| 1.1 | **SwiftData Models** | `Conversation`, `Message`, `MessagePart` (text/image/file), `Attachment`, `ChatSettings` — with branching support (each message has optional `parentMessageId`) |
| 1.2 | **GeminiAPIClient** | Async/await REST client: `generateContent`, `streamGenerateContent`, model listing. API key stored in Keychain. Supports all `GenerationConfig` params (temperature, topP, topK, maxOutputTokens, thinkingBudget, responseModalities) |
| 1.3 | **Chat View** | SwiftUI chat UI with markdown rendering (using `AttributedString` or a markdown lib), syntax-highlighted code blocks, copy buttons, image display, streaming token animation |
| 1.4 | **Conversation List** | Sidebar/list of conversations with search, swipe-to-delete, pin, archive |
| 1.5 | **Settings & API Key Management** | Keychain-stored API key entry, model selection, default parameters |

### Phase 2: History Editing & Branching (The Killer Feature)
> What makes this app *better*

| # | Work Unit | Details |
|---|-----------|---------|
| 2.1 | **Message Tree Model** | Each message stores `parentId`, enabling tree-based conversation branching. UI shows the active branch with sibling navigation (left/right arrows like ChatGPT) |
| 2.2 | **Regenerate from Point** | Tap any assistant message → "Regenerate". Forks the conversation at that point, sends all messages up to the parent as context, generates a new response on a new branch |
| 2.3 | **Edit & Re-send** | Tap any user message → "Edit". Modify text, re-send. Creates a new branch from that point |
| 2.4 | **Rollback / Truncate** | Long-press any message → "Delete everything after this". Removes all descendants, sets this as the conversation endpoint |
| 2.5 | **Branch Navigator** | Visual indicator showing "Response 2 of 3" with arrows to switch between sibling branches |

### Phase 3: Multimodal Input/Output
> Images, documents, audio, video

| # | Work Unit | Details |
|---|-----------|---------|
| 3.1 | **Image Input** | Camera capture, photo library picker, paste from clipboard. Sends as `inlineData` (base64) or via File API for large images |
| 3.2 | **Document Input** | PDF picker, document scanner. Sends via File API. Display thumbnail preview in chat |
| 3.3 | **Audio Input** | Microphone recording → send as audio/wav part for audio understanding |
| 3.4 | **Nano Banana Image Generation** | Detect image parts in responses, render inline. Support `responseModalities: ['TEXT', 'IMAGE']`. Aspect ratio picker, resolution picker (1K/2K/4K for Pro Image) |
| 3.5 | **Nano Banana Image Editing** | Multi-turn image editing: send previous images + edit instructions. Gallery view for generated images with save/share |
| 3.6 | **Video Input** | Video picker → upload via File API → send reference for video understanding |

### Phase 4: Tools & Grounding
> Google Search, URL Context, Code Execution, Function Calling

| # | Work Unit | Details |
|---|-----------|---------|
| 4.1 | **Google Search Grounding** | Toggle per-chat. Display grounding metadata: source links, search suggestions |
| 4.2 | **URL Context** | Paste a URL in chat → automatically detected and sent as URL context tool |
| 4.3 | **Code Execution** | Enable code execution tool. Display executed code and output in collapsible blocks |
| 4.4 | **Google Maps Grounding** | Toggle on for location-aware queries. Display map results inline |
| 4.5 | **Function Calling UI** | Define custom functions per chat (name, description, parameters as JSON schema). Display function call/response cycle in chat |
| 4.6 | **Structured Output Mode** | Toggle JSON mode. Define response schema. Display formatted JSON with syntax highlighting |

### Phase 5: Voice & Live API
> Real-time voice conversations

| # | Work Unit | Details |
|---|-----------|---------|
| 5.1 | **Live API Client** | WebSocket connection manager for Live API. Handle `sendRealtimeInput`, `receive()`, voice activity detection, interruption handling |
| 5.2 | **Voice Conversation UI** | Full-screen voice mode with animated waveform, tap-to-mute, speaker toggle. Uses native audio model (`gemini-2.5-flash-native-audio`) |
| 5.3 | **TTS for Responses** | "Read aloud" button on any text response. Uses `gemini-2.5-flash-preview-tts` with voice picker (30 voices). Plays PCM audio via `AVAudioPlayer` |
| 5.4 | **Audio Session Management** | Proper `AVAudioSession` configuration: handle interruptions, route changes, bluetooth, speaker/earpiece |

### Phase 6: Deep Research
> Long-running autonomous research tasks

| # | Work Unit | Details |
|---|-----------|---------|
| 6.1 | **Interactions API Client** | REST client for `interactions.create`, `interactions.get`. Background polling with streaming support |
| 6.2 | **Deep Research UI** | Dedicated research view showing progress (thinking summaries), intermediate steps, and final cited report. Markdown rendering with source links |
| 6.3 | **Research History** | Persist research results. Browse, search, and re-open past research |

### Phase 7: Privacy & Power Features
> What makes power users love this app

| # | Work Unit | Details |
|---|-----------|---------|
| 7.1 | **Private Chats** | Conversations stored only on-device. No sync, no cloud. Optional Face ID/Touch ID lock on the app or per-conversation |
| 7.2 | **Export** | Export conversation as Markdown, JSON, or PDF. Share sheet integration |
| 7.3 | **System Instructions** | Per-conversation system instruction editor. Library of saved personas/instructions |
| 7.4 | **Model Selector** | Pick any available model per conversation: Gemini 3 Pro, 3 Flash, 2.5 Pro, 2.5 Flash, etc. Display model capabilities |
| 7.5 | **Parameter Controls** | Sliders for temperature, topP, topK, maxOutputTokens, thinkingBudget. Presets (Creative, Precise, Balanced) |
| 7.6 | **Token Counter** | Display input/output/cached token counts per message and total conversation usage |
| 7.7 | **Context Caching** | For long conversations, create context caches to reduce costs and latency |
| 7.8 | **iCloud Sync** | Optional iCloud sync for conversations (not private ones) using CloudKit |
| 7.9 | **Keyboard Shortcuts** | Full keyboard support for iPad: Cmd+N (new chat), Cmd+Enter (send), Cmd+Shift+C (copy last response) |
| 7.10 | **Haptics & Gestures** | Haptic feedback on send, swipe to navigate branches, pull to refresh |

### Phase 8: Polish & Video/Audio Generation
> Advanced generation features

| # | Work Unit | Details |
|---|-----------|---------|
| 8.1 | **Veo Video Generation** | Text/image → video generation via Veo 3.1. Video player inline in chat with save/share |
| 8.2 | **Lyria Music Generation** | Text → music generation. Audio player inline |
| 8.3 | **Thinking Mode Visualization** | Display thinking process: show thinking text, interim thought images, thinking budget usage |
| 8.4 | **Safety Settings** | Per-conversation safety setting overrides (harassment, hate, sexual, dangerous) |
| 8.5 | **Dark/Light/System Theme** | Full theme support with accent color customization |
| 8.6 | **Widget** | iOS widget showing recent conversations or quick-start a new chat |
| 8.7 | **Shortcuts Integration** | Siri Shortcuts: "Ask Gemini..." for quick queries from anywhere |

---

## Project Structure

```
better/
├── App/
│   ├── betterApp.swift
│   └── AppState.swift
├── Models/
│   ├── Conversation.swift          # SwiftData model
│   ├── Message.swift               # With parentId for branching
│   ├── MessagePart.swift           # Text, image, file, audio, video
│   ├── ChatSettings.swift          # Per-conversation settings
│   └── SystemInstruction.swift     # Saved personas
├── Services/
│   ├── GeminiAPIClient.swift       # Core REST client
│   ├── GeminiStreamParser.swift    # SSE stream parser
│   ├── LiveAPIClient.swift         # WebSocket Live API
│   ├── InteractionsClient.swift    # Deep Research
│   ├── FileAPIClient.swift         # File upload/management
│   ├── KeychainService.swift       # API key storage
│   └── AudioService.swift          # Recording/playback
├── ViewModels/
│   ├── ChatViewModel.swift
│   ├── ConversationListViewModel.swift
│   ├── VoiceViewModel.swift
│   ├── ResearchViewModel.swift
│   └── SettingsViewModel.swift
├── Views/
│   ├── Chat/
│   │   ├── ChatView.swift
│   │   ├── MessageBubble.swift
│   │   ├── MessageInput.swift
│   │   ├── BranchNavigator.swift
│   │   ├── CodeBlockView.swift
│   │   └── ImageGenerationView.swift
│   ├── Conversations/
│   │   ├── ConversationListView.swift
│   │   └── ConversationRow.swift
│   ├── Voice/
│   │   ├── LiveVoiceView.swift
│   │   └── WaveformView.swift
│   ├── Research/
│   │   ├── DeepResearchView.swift
│   │   └── ResearchProgressView.swift
│   ├── Settings/
│   │   ├── SettingsView.swift
│   │   ├── ModelPickerView.swift
│   │   ├── ParameterControlsView.swift
│   │   └── SystemInstructionEditor.swift
│   └── Shared/
│       ├── MarkdownRenderer.swift
│       ├── ImageViewer.swift
│       └── LoadingIndicator.swift
├── Utilities/
│   ├── Extensions/
│   ├── Constants.swift
│   └── Haptics.swift
└── Assets.xcassets/
```

---

## Implementation Approach

- **Swift 6** with strict concurrency
- **SwiftUI** for all views
- **SwiftData** for persistence (conversation tree with parent references)
- **URLSession** async/await for REST API calls
- **URLSessionWebSocketTask** for Live API
- **AVFoundation** for audio recording/playback
- **PhotosUI** for image/video picking
- No third-party dependencies initially (consider `swift-markdown` for rendering)

---

## Recommended Build Order

**Start with Phases 1 + 2** (foundation + the killer feature of history editing). This gives a working chat app that's already better than Google's. Then layer on multimodal (Phase 3), tools (Phase 4), voice (Phase 5), and the rest incrementally.

## Gemini API Reference

### Base URL
```
https://generativelanguage.googleapis.com/v1beta/
```

### Key Endpoints
- `POST models/{model}:generateContent` — Single response
- `POST models/{model}:streamGenerateContent?alt=sse` — Streaming (SSE)
- `GET models` — List available models
- `POST files` — Upload files
- `GET files/{name}` — Get file metadata
- `DELETE files/{name}` — Delete file
- `POST cachedContents` — Create context cache

### Models (as of Feb 2026)
- `gemini-3-pro` / `gemini-3-pro-preview` — Most intelligent
- `gemini-3-flash` / `gemini-3-flash-preview` — Balanced speed/intelligence
- `gemini-2.5-pro` — Advanced thinking
- `gemini-2.5-flash` — Best price-performance
- `gemini-2.5-flash-lite` — Fastest/cheapest
- `gemini-2.5-flash-image` — Nano Banana (image gen)
- `gemini-3-pro-image-preview` — Nano Banana Pro (4K image gen)
- `gemini-2.5-flash-preview-tts` — Text-to-speech
- `gemini-2.5-flash-native-audio-preview` — Live API native audio

### Request Body Structure
```json
{
  "contents": [
    {
      "role": "user" | "model",
      "parts": [
        { "text": "..." },
        { "inlineData": { "mimeType": "image/png", "data": "<base64>" } },
        { "fileData": { "mimeType": "...", "fileUri": "..." } }
      ]
    }
  ],
  "systemInstruction": {
    "parts": [{ "text": "..." }]
  },
  "generationConfig": {
    "temperature": 0.0-2.0,
    "topP": 0.0-1.0,
    "topK": 1-100,
    "maxOutputTokens": int,
    "responseMimeType": "text/plain" | "application/json",
    "responseSchema": { ... },
    "responseModalities": ["TEXT", "IMAGE"],
    "thinkingConfig": { "thinkingBudget": int }
  },
  "tools": [
    { "googleSearch": {} },
    { "urlContext": {} },
    { "codeExecution": {} },
    { "functionDeclarations": [...] }
  ],
  "safetySettings": [
    { "category": "HARM_CATEGORY_...", "threshold": "BLOCK_..." }
  ]
}
```
