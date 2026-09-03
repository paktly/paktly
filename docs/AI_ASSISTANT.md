# Ask Paktly

Speak to Paktly converts a short voice command into a reviewable action draft. It supports creating an equal-split expense, creating a plan, and inviting one person.

The iOS app records a short `.m4a` command and sends it to authenticated `POST /api/v1/assistant/transcribe`. The backend transcribes it, and then `POST /api/v1/assistant/interpret` supplies only the transcript plus the current user's accessible plans and active members to OpenAI for a strict structured response. Neither endpoint mutates product data. The user must review and explicitly confirm the draft before Paktly calls its existing typed mutation endpoints. The iOS app never receives an OpenAI API key.

## Production configuration

```env
AI_ASSISTANT_ENABLED=true
OPENAI_API_KEY=YOUR_SERVER_SIDE_OPENAI_API_KEY
OPENAI_MODEL=gpt-5.4-mini
OPENAI_TRANSCRIPTION_MODEL=gpt-4o-transcribe
```

The model is configurable so it can be upgraded without an iOS release. Prompts are limited to 1,000 characters, interpretation is rate-limited, OpenAI response storage is disabled, model-selected IDs are checked against server-side membership, and provider errors are returned as generic service errors.

Recordings are capped by the client and upload size is capped by the API. Audio is held only long enough to submit the transcription request and is not written to application storage. Receipt extraction remains a separate future capability.
