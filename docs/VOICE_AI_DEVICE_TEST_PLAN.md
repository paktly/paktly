# Speak to Paktly physical-device test plan

Run this matrix on a signed physical iPhone build against staging before release. Record device, iOS version, build SHA, network, result, latency, and any request ID. Never record real financial or sensitive speech in test evidence.

## Happy paths

- Create a new plan with a name, description, and relative dates.
- Add an equal expense in the current plan and from Home using an exact plan name.
- Add exact, percentage, shares, and itemized expenses; verify totals and members in the preview and persisted expense.
- Invite an existing username and an external email.
- Tap Confirm twice and retry after a connection interruption; exactly one action may exist.
- Speak for 60 seconds and verify automatic stopping.

## Failure paths

- Deny microphone permission, then enable it in Settings and retry.
- Start on Wi-Fi, move to cellular, and disable networking mid-stream.
- Let a confirmation preview expire before confirming.
- Use an ambiguous plan name, duplicate member display names, unknown members, invalid percentages, and missing amounts.
- Background and foreground the app while recording; answer a call; connect/disconnect Bluetooth audio.
- Exhaust minute and daily limits and verify actionable, non-provider error messages.
- Revoke the session while the sheet is open and verify no action executes.

## Release gates

- No permanent OpenAI credential appears in the app binary, device logs, or proxy captures.
- Audio and transcript content do not appear in application logs or analytics.
- Voice data is removed from temporary device storage after success, cancellation, and failure.
- VoiceOver announces recording, stop, processing, clarification, preview, and confirmation states.
- P95 preview latency and Realtime session failures meet the staging SLO documented in `AI_ASSISTANT.md`.
