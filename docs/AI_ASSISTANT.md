# Ask Paktly

Speak to Paktly converts a short voice command into a reviewable action draft. It supports creating an equal-split expense, creating a plan, and inviting one person.

The iOS app records a short audio command and shows a live transcript while the user speaks. When live text is available, it is sent directly to `POST /api/v1/assistant/interpret`; completed-audio transcription remains a fallback when the device produces no live text. The interpretation endpoint supplies only the transcript plus the current user's accessible plans and active members to OpenAI for a strict structured response. Neither endpoint mutates product data. The user must review and explicitly confirm the draft before Paktly calls its existing typed mutation endpoints. The iOS app never receives an OpenAI API key.

## Production configuration

```env
AI_ASSISTANT_ENABLED=true
OPENAI_API_KEY=YOUR_SERVER_SIDE_OPENAI_API_KEY
OPENAI_MODEL=gpt-5.4-mini
OPENAI_TRANSCRIPTION_MODEL=gpt-4o-transcribe
OPENAI_REALTIME_TRANSCRIPTION_MODEL=gpt-live-transcribe
ASSISTANT_DRAFT_SECRET=GENERATE_A_STRONG_RANDOM_SECRET
```

The model is configurable so it can be upgraded without an iOS release. Prompts are limited to 1,000 characters, interpretation is rate-limited, OpenAI response storage is disabled, model-selected IDs are checked against server-side membership, and provider errors are returned as generic service errors.

Recordings are capped by the client and upload size is capped by the API. Audio is held only long enough to submit the transcription request and is not written to application storage. Receipt extraction remains a separate future capability.
# Security and operational controls

- The permanent OpenAI API key remains server-side. Mobile clients request short-lived Realtime transcription credentials from the authenticated, rate-limited API.
- Interpretations return an HMAC-signed, actor-bound draft that expires after five minutes. `/assistant/confirm` verifies it and records an idempotency key before the client applies the verified draft.
- Per-minute and per-day user limits bound session creation, interpretations, and fallback audio bytes. Uploads are capped at 12 MB and recordings at 60 seconds in iOS.
- Logs contain event name, intent, latency, status, and opaque draft ID only—never audio or transcript text.
- Target staging SLO: 99% session issuance success excluding upstream outages; P95 action-preview latency below five seconds after speech completion.

# Realtime transcription

Production uses `gpt-live-transcribe` with a server-issued ephemeral credential. Completed-file transcription remains a bounded fallback. Apple Speech is not a source of truth for an action and should be removed after Realtime device validation.
