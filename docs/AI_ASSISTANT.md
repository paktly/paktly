# Ask Paktly

Ask Paktly converts natural-language requests into reviewable action drafts. It supports creating an equal-split expense, creating a plan, and inviting one person.

The iOS app never receives an OpenAI API key. It sends an authenticated request to `POST /api/v1/assistant/interpret`; the API supplies only the current user's accessible plans and active members to OpenAI and requests a strict structured response. The endpoint does not mutate data. The user must review and explicitly confirm the draft before Paktly calls its existing typed mutation endpoints.

## Production configuration

```env
AI_ASSISTANT_ENABLED=true
OPENAI_API_KEY=YOUR_SERVER_SIDE_OPENAI_API_KEY
OPENAI_MODEL=gpt-5.4-mini
```

The model is configurable so it can be upgraded without an iOS release. Prompts are limited to 1,000 characters, interpretation is rate-limited, OpenAI response storage is disabled, model-selected IDs are checked against server-side membership, and provider errors are returned as generic service errors.

Voice input and receipt extraction are separate future capabilities. Neither is represented as functional until its capture, consent, and validation flows are implemented.
