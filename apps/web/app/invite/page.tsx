import type { Metadata } from "next";
import Link from "next/link";
import { PaktlyMark } from "../../components/paktly-mark";

export const metadata: Metadata = {
  title: "Plan invitation | Paktly",
  description: "Open a secure invitation to a shared Paktly plan.",
  robots: { index: false, follow: false }
};

export default async function InvitationPage({
  searchParams
}: {
  searchParams: Promise<{ token?: string }>;
}) {
  const token = (await searchParams).token?.trim() ?? "";
  const valid = /^[A-Za-z0-9_-]{20,200}$/.test(token);
  const appLink = valid ? `paktly://invite?token=${encodeURIComponent(token)}` : null;

  return (
    <section className="container invitation-page">
      <div className="invitation-card">
        <div className="invitation-mark" aria-hidden="true"><PaktlyMark /></div>
        <span className="section-kicker">SHARED PLAN INVITATION</span>
        <h1>{valid ? "You’ve been invited." : "This invitation link isn’t valid."}</h1>
        <p>{valid
          ? "Open Paktly to accept the invitation. If you’re new, create your account with the same email address that received the invitation and it will be waiting for you."
          : "Ask the plan organizer to send a new invitation. Invitations expire after seven days and can only be used once."}</p>
        <div className="invitation-actions">
          {appLink ? <a className="button primary" href={appLink}>Open in Paktly <span>→</span></a> : null}
          <Link className="text-link" href={valid ? "/download" : "/support"}>{valid ? "Get Paktly" : "Contact support"}</Link>
        </div>
        <small>Only accept invitations you recognize. Paktly will never ask for a seed phrase or payment to join a plan.</small>
      </div>
    </section>
  );
}
