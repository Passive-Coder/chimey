# chimey optional assistance

Node 22+ only, with no Python, package dependencies, clip persistence, or request-content logging.

1. Copy `.env.example` to `.env` locally.
2. Configure a Gemini API key and a random service token (at least 24 characters). Keep the provider key on this server. Generate a token with `node -e "console.log(require('node:crypto').randomBytes(32).toString('hex'))"`.
3. Run `npm start` in this directory. The default bind is loopback; use an authenticated HTTPS reverse proxy to serve a phone. Enter that HTTPS address and the service token in the app's Understand a sound screen.
4. Choose audio analysis or text research and confirm sharing for each request. Audio is 1–8 seconds of 16 kHz mono PCM16 WAV. Text research sends only the typed description.

`POST /analyze` and `POST /research` require `Authorization: Bearer <service token>` and JSON with `consent: true`. Analysis additionally takes `audio` (base64 WAV); research takes `description` (1–600 characters). Responses are always `kind: explanation`, `confirmed: false`; they never contain action commands. Text research preserves citation text, HTTPS source links, and Google search suggestions. The client displays suggestions with a non-script HTML renderer.

The provider integration uses the current Interactions REST API with inline audio, a separate Google Search request, and `store: false`. The default model is configurable. See [audio understanding](https://ai.google.dev/gemini-api/docs/audio) and [search grounding](https://ai.google.dev/gemini-api/docs/google-search). Google 2.5 model access is currently restricted to existing users; this project defaults to Gemini 3.8 Flash per the current [model catalog](https://ai.google.dev/gemini-api/docs/models).

`npm test` checks authentication, origin restrictions, explicit consent, WAV contract, actual encoded audio forwarding, distinct research requests, citation filtering, and upstream failures using an injected provider transport. Live provider performance remains unverified until valid credentials are configured. Server requests are bounded and limited to six per minute per client address. Deployers should keep provider credentials and the service behind their normal access controls.
