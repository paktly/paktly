"use client";

import { useState, type FormEvent } from "react";

type SubmissionState = "idle" | "submitting" | "success" | "error";

export function WaitlistForm() {
  const [state, setState] = useState<SubmissionState>("idle");
  const [message, setMessage] = useState("");

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setState("submitting");
    setMessage("");
    const form = event.currentTarget;
    const data = new FormData(form);
    try {
      const response = await fetch("/api/waitlist", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ email: data.get("email"), marketingConsent: data.get("marketingConsent") === "on", termsAcknowledged: data.get("termsAcknowledged") === "on", company: data.get("company") }) });
      const payload = (await response.json()) as { message?: string };
      if (!response.ok) throw new Error(payload.message ?? "Submission failed");
      form.reset();
      setState("success");
      setMessage("You’re on the list. We’ll only send meaningful product updates.");
    } catch {
      setState("error");
      setMessage("We couldn’t save your request. Please try again in a moment.");
    }
  }

  return <form className="waitlist-form" onSubmit={(event) => void submit(event)}><div className="waitlist-fields"><label><span>Email address</span><input name="email" type="email" autoComplete="email" inputMode="email" required placeholder="you@example.com" /></label><label className="honeypot" aria-hidden="true">Company<input name="company" tabIndex={-1} autoComplete="off" /></label><button type="submit" disabled={state === "submitting"}>{state === "submitting" ? "Joining…" : "Join the waitlist"}<span aria-hidden="true">→</span></button></div><label className="consent-row"><input name="marketingConsent" type="checkbox" required /><span>I agree to receive prelaunch product updates. I can unsubscribe at any time.</span></label><label className="consent-row"><input name="termsAcknowledged" type="checkbox" required /><span>I acknowledge the <a href="/terms">Terms of Use</a> and <a href="/privacy">Privacy Policy</a>.</span></label><p className={`form-status ${state}`} role="status" aria-live="polite">{message}</p></form>;
}
