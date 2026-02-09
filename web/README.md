# Better Web

## Prerequisites

- Node.js 18+
- Firebase CLI (`npm install -g firebase-tools`)

## Setup

1. Install dependencies:
   `cd web && npm install`
2. Generate Firebase config and write the local .env file:
   `npm run setup:firebase`
3. Run the dev server:
   `npm run dev`

## Environment Variables

The web app expects Firebase config values in `.env` (see `.env.example`).

- `VITE_FIREBASE_API_KEY`
- `VITE_FIREBASE_AUTH_DOMAIN`
- `VITE_FIREBASE_PROJECT_ID`
- `VITE_FIREBASE_STORAGE_BUCKET`
- `VITE_FIREBASE_MESSAGING_SENDER_ID`
- `VITE_FIREBASE_APP_ID`
- `VITE_FIREBASE_MEASUREMENT_ID` (optional)

## Scripts

- `npm run dev` - start the Vite dev server
- `npm run build` - build for production
- `npm run preview` - preview the production build locally
- `npm run test` - run Vitest in watch mode
- `npm run test:ui` - open the Vitest UI
- `npm run test:coverage` - generate coverage reports
- `npm run lint` - run ESLint
- `npm run lint:fix` - fix lint issues where possible
- `npm run type-check` - run TypeScript checks
- `npm run setup:firebase` - generate `.env` from Firebase app config
- `npm run deploy` - build and deploy to Firebase Hosting

## Development Workflow

1. `npm run dev`
2. `npm run lint` and `npm run type-check` before committing
3. `npm run test` for focused changes or `npm run test:coverage` for CI-style checks

## Testing Guide

- Test runner: Vitest + jsdom
- DOM assertions: `@testing-library/jest-dom`
- Integration tests live in `src/test/integration`

## Deployment

1. Ensure Firebase CLI is authenticated and the project is selected.
2. Run `npm run deploy`.

## Architecture Overview

- Vite + React frontend
- Firebase Auth, Firestore, and Storage for backend services
- Gemini REST client in `src/services/gemini`
- App state via React Context stores in `src/state`

## Notes

- A Gemini API key is required for chat responses. The web app will prompt for it and store it locally.
- See the repository README for Firebase project setup details.
