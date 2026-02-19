# 🏆 AI Chess Arena - Multi-Model Battle Royale

A visually stunning 3D chess application where AI models compete against each other in real-time.

## Vision

A cinematic 3D chess experience where you select AI models and watch them battle. Think Wizard's Chess from Harry Potter meets AI benchmarking.

```
┌────────────────────────────────────────────────────────────────┐
│                                                                │
│    ╔═══════════════════════════════════════════════════════╗   │
│    ║              AI CHESS ARENA                           ║   │
│    ╚═══════════════════════════════════════════════════════╝   │
│                                                                │
│         [Claude Opus]  ⚔️  vs  ⚔️  [GPT-5]                     │
│              14:32          ●          12:45                   │
│                                                                │
│                      ╔══════════╗                              │
│                   ╔══╝  ♜    ♞  ╚══╗                           │
│                ╔══╝ ♟  ♝  ♛  ♚  ♝  ╚══╗                        │
│             ╔══╝  ♟  ♟  ♟  ♟  ♟  ♟  ♟  ╚══╗                    │
│            ║    ·   ·   ·   ·   ·   ·   ·  ║                   │
│            ║  ·   ·   ·   ♙   ·   ·   ·   ·║   3D BOARD        │
│            ║    ·   ·   ♙   ·   ·   ·   ·  ║   with lighting   │
│             ╚══╗ ♙  ♙  ♙     ♙  ♙  ♙  ♙ ╔══╝   & animations    │
│                ╚══╗ ♖  ♘  ♗  ♕  ♔  ♗ ╔══╝                      │
│                   ╚══╗  ♘  ♖     ╔══╝                          │
│                      ╚══════════╝                              │
│                                                                │
│   Move History          │  Live Analysis                       │
│   1. e4    e5           │  "Opus is playing aggressively..."   │
│   2. Nf3   Nc6          │  "GPT-5 responds with Sicilian..."   │
│   3. Bb5   a6           │                                      │
│                                                                │
│   [⏸ Pause]  [⏭ Next]  [🔄 New Game]  [📊 Tournament]          │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

---

## Tech Stack

### Frontend (3D Visualization)
- **Three.js** - 3D rendering engine
- **React Three Fiber** - React bindings for Three.js
- **Drei** - Useful Three.js helpers
- **Framer Motion** - UI animations
- **Tailwind CSS** - Styling

### Backend (Game Engine + AI)
- **Node.js/TypeScript** - Server runtime
- **@github/copilot-sdk** - Wraps Copilot CLI for model access
- **chess.js** - Move validation, game state, PGN
- **Socket.io** - Real-time game updates to frontend

### AI Integration via Copilot SDK

```typescript
import { CopilotClient } from '@github/copilot-sdk';

const client = new CopilotClient();

// Get move from a specific model
async function getAIMove(model: string, board: string, moveHistory: string[]) {
  const response = await client.prompt({
    model: model, // 'claude-opus-4', 'gpt-5', 'gemini-pro', etc.
    prompt: `You are playing chess as ${color}. 
             Current board (FEN): ${board}
             Move history: ${moveHistory.join(', ')}
             
             Respond with ONLY your move in algebraic notation (e.g., "e4", "Nf3", "O-O").
             Think carefully - this is a competitive match.`,
  });
  
  return parseMove(response.text);
}
```

---

## Features

### 1. Model Selection
Pick any two models to compete:

| Model | Expected Style |
|-------|---------------|
| `claude-opus-4` | Deep strategic thinking |
| `claude-sonnet-4` | Balanced, efficient |
| `gpt-5` | Pattern recognition |
| `gemini-pro` | Multimodal reasoning |
| `claude-haiku-4` | Speed demon (underdog) |

### 2. 3D Chess Board
- **Realistic pieces** - Detailed 3D models with materials
- **Dynamic lighting** - Dramatic shadows, spotlight on active piece
- **Smooth animations** - Pieces glide, captures have effects
- **Camera controls** - Orbit, zoom, preset angles
- **Particle effects** - Captures explode, checks flash

### 3. Real-Time Commentary
AI-generated commentary on the game:
```
"Opus opens with the Sicilian Defense - a fighting choice!"
"GPT-5 sacrifices a knight... is this brilliance or blunder?"
"Both models are in time pressure now..."
```

### 4. Tournament Mode
```
┌─────────────────────────────────────────┐
│         ROUND ROBIN TOURNAMENT          │
├─────────────────────────────────────────┤
│                W   D   L   Pts          │
│  Claude Opus   5   2   1   12           │
│  GPT-5         4   3   1   11           │
│  Gemini Pro    3   2   3    8           │
│  Sonnet        2   4   2    8           │
│  Haiku         1   1   6    3           │
├─────────────────────────────────────────┤
│  Games: 20/20 complete                  │
│  [View All Games] [Export PGN]          │
└─────────────────────────────────────────┘
```

### 5. Game Analysis
- Move-by-move replay with scrubber
- Branching visualization (what if AI played differently?)
- Export to PGN for external analysis
- Heatmaps showing piece activity

---

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                        FRONTEND                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │  Three.js   │  │   React     │  │   Socket.io Client  │  │
│  │  3D Board   │  │   UI/HUD    │  │   Real-time updates │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
                              │
                              │ WebSocket
                              ▼
┌──────────────────────────────────────────────────────────────┐
│                        BACKEND                               │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │  Game       │  │  Copilot    │  │   Socket.io Server  │  │
│  │  Engine     │◄─┤  SDK        │  │   Broadcast moves   │  │
│  │  (chess.js) │  │  (AI moves) │  │                     │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
│         │                │                                   │
│         ▼                ▼                                   │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                   Game State                         │    │
│  │  - Board position (FEN)                              │    │
│  │  - Move history (PGN)                                │    │
│  │  - Clocks                                            │    │
│  │  - Tournament standings                              │    │
│  └─────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────┘
                              │
                              │ JSON-RPC
                              ▼
┌──────────────────────────────────────────────────────────────┐
│                    COPILOT CLI (Server Mode)                 │
│                                                              │
│   Routes requests to selected model:                         │
│   - claude-opus-4                                            │
│   - claude-sonnet-4                                          │
│   - gpt-5                                                    │
│   - gemini-pro                                               │
│   - etc.                                                     │
└──────────────────────────────────────────────────────────────┘
```

---

## Project Structure

```
chess-arena/
├── frontend/
│   ├── src/
│   │   ├── components/
│   │   │   ├── Board3D/
│   │   │   │   ├── Board.tsx        # 3D board mesh
│   │   │   │   ├── Piece.tsx        # Individual piece component
│   │   │   │   ├── Square.tsx       # Board squares with highlights
│   │   │   │   └── CaptureEffect.tsx
│   │   │   ├── HUD/
│   │   │   │   ├── PlayerCard.tsx   # Model name, clock, captures
│   │   │   │   ├── MoveHistory.tsx  # Scrollable move list
│   │   │   │   └── Commentary.tsx   # AI-generated commentary
│   │   │   ├── Controls/
│   │   │   │   ├── ModelPicker.tsx  # Dropdown to select models
│   │   │   │   ├── GameControls.tsx # Play/pause/reset
│   │   │   │   └── CameraPresets.tsx
│   │   │   └── Tournament/
│   │   │       ├── Standings.tsx
│   │   │       └── BracketView.tsx
│   │   ├── hooks/
│   │   │   ├── useGame.ts           # Socket connection, game state
│   │   │   └── useCamera.ts         # 3D camera controls
│   │   ├── lib/
│   │   │   └── socket.ts            # Socket.io client
│   │   └── App.tsx
│   └── public/
│       └── models/                   # 3D piece models (.glb)
│
├── backend/
│   ├── src/
│   │   ├── game/
│   │   │   ├── ChessGame.ts         # Wraps chess.js
│   │   │   ├── Tournament.ts        # Multi-game management
│   │   │   └── Clock.ts             # Time control
│   │   ├── ai/
│   │   │   ├── ModelPlayer.ts       # Copilot SDK wrapper
│   │   │   ├── prompts.ts           # Chess prompts per model
│   │   │   └── moveParser.ts        # Extract move from response
│   │   ├── commentary/
│   │   │   └── Commentator.ts       # Generate play-by-play
│   │   └── server.ts                # Express + Socket.io
│   └── package.json
│
├── shared/
│   └── types.ts                      # Shared TypeScript types
│
└── README.md
```

---

## Game Flow

```
1. USER selects White model (e.g., Claude Opus)
2. USER selects Black model (e.g., GPT-5)
3. USER clicks "Start Game"
4. BACKEND initializes chess.js game
5. LOOP:
   a. BACKEND sends board state to current player's model via Copilot SDK
   b. MODEL returns move in algebraic notation
   c. BACKEND validates move with chess.js
   d. If invalid → retry with error message (max 3 attempts)
   e. If valid → apply move, broadcast to frontend
   f. FRONTEND animates piece movement
   g. COMMENTATOR generates quip about the move
   h. Check for checkmate/stalemate/draw
   i. Switch active player
6. GAME OVER → display result, offer rematch or tournament
```

---

## Visual Effects Wishlist

### Piece Animations
- **Move**: Smooth glide with slight hover
- **Capture**: Captured piece shatters/fades, particles fly
- **Castle**: Both pieces move simultaneously
- **Promotion**: Pawn transforms with glow effect
- **Check**: King square pulses red, dramatic camera shake
- **Checkmate**: Spotlight on winning piece, confetti

### Board Effects
- **Legal moves**: Subtle glow on valid squares when hovering
- **Last move**: Highlighted squares (from/to)
- **Attack lines**: Optional visualization of piece threats

### Atmosphere
- **Environment map**: Dark studio with dramatic lighting
- **Fog**: Subtle depth fog for cinematic feel
- **Ambient particles**: Floating dust motes

---

## Implementation Phases

### Phase 1: Core Engine (Week 1)
- [ ] Backend with chess.js game logic
- [ ] Copilot SDK integration for AI moves
- [ ] Socket.io real-time communication
- [ ] Basic move validation and retry logic

### Phase 2: 3D Board (Week 2)
- [ ] Three.js scene setup
- [ ] 3D piece models (find/create .glb files)
- [ ] Board rendering with materials
- [ ] Basic piece movement animations

### Phase 3: UI/UX (Week 3)
- [ ] Model selection dropdowns
- [ ] Game controls (start/pause/reset)
- [ ] Move history panel
- [ ] Player cards with clocks

### Phase 4: Polish (Week 4)
- [ ] Capture effects and particles
- [ ] Camera presets and controls
- [ ] AI commentary system
- [ ] Sound effects

### Phase 5: Tournament Mode (Week 5)
- [ ] Multi-game scheduling
- [ ] Standings table
- [ ] Statistics tracking
- [ ] PGN export

---

## Prompt Engineering for Chess

Key considerations for getting good moves from LLMs:

```typescript
const CHESS_PROMPT = `You are a chess grandmaster playing a competitive match.

CRITICAL RULES:
1. Respond with ONLY the move in standard algebraic notation
2. Examples: "e4", "Nf3", "Bxc6", "O-O", "O-O-O", "e8=Q"
3. Do NOT include move numbers, commentary, or explanation
4. The move MUST be legal in the current position

Current position (FEN): {fen}
You are playing as: {color}
Move history: {moves}
Your opponent: {opponent_model}

Your move:`;
```

**Handling invalid moves:**
```typescript
const RETRY_PROMPT = `Your previous move "{invalid_move}" is illegal.
Legal moves are: {legal_moves}

Pick ONE legal move from the list above.
Respond with ONLY the move, nothing else.`;
```

---

## Potential Model Personalities

Add flavor by varying prompts per model:

| Model | Personality Prompt Addition |
|-------|---------------------------|
| Opus | "You are a patient strategic thinker. Prefer solid positional play." |
| GPT-5 | "You are an aggressive tactician. Look for sacrifices and combinations." |
| Gemini | "You are an unpredictable creative. Surprise your opponent." |
| Sonnet | "You are a practical player. Choose the most reliable move." |
| Haiku | "You play fast and instinctively. Trust your intuition." |

---

## Success Metrics

1. **Moves per second**: Target < 5s per AI move
2. **Invalid move rate**: Target < 10% (with retries)
3. **Game completion rate**: Target > 95%
4. **Visual smoothness**: 60fps on mid-range hardware

---

## Open Questions

1. **Time controls**: Should models have time limits? (Adds pressure but might increase errors)
2. **Thinking display**: Show model's reasoning? (Interesting but slow)
3. **Human play**: Allow human vs AI mode?
4. **Elo tracking**: Calculate ratings for each model over time?
5. **Opening books**: Give models opening theory? Or let them figure it out?

---

## Next Steps

1. Verify Copilot SDK access and model availability
2. Scaffold the monorepo (frontend + backend)
3. Implement basic game loop with one model
4. Add 3D board rendering
5. Iterate on visuals and UX
