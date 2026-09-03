import type { Metadata } from "next";
import Link from "next/link";
import { PaktlyMark } from "../../components/paktly-mark";

export const metadata: Metadata = {
  title: "Join a shared plan | Paktly",
  description: "Review an invitation to join a shared Paktly plan.",
  robots: { index: false, follow: false }
};

export default async function JoinPage({
  searchParams
}: {
  searchParams: Promise<{ token?: string }>;
}) {
  const token = (await searchParams).token?.trim() ?? "";
  const valid = /^[A-Za-z0-9_-]{20,200}$/.test(token);
  const appLink = valid ? `paktly://join?token=${encodeURIComponent(token)}` : null;

  return (
    <section className="container invitation-page">
      <div className="invitation-card">
        <div className="invitation-mark" aria-hidden="true"><PaktlyMark /></div>
        <span className="section-kicker">SHARED PLAN INVITATION</span>
        <h1>{valid ? "Join the plan in Paktly." : "This invite link isn’t valid."}</h1>
        <p>{valid
          ? "Open Paktly to review the plan and choose whether to join. If you’re new, create your account first—the invitation will still be waiting."
          : "Ask the plan organizer to create a new link. Share links can expire, reach their join limit, or be revoked."}</p>
        <div className="invitation-actions">
          {appLink ? <a className="button primary" href={appLink}>Open in Paktly <span>→</span></a> : null}
          <Link className="text-link" href={valid ? "/download" : "/support"}>{valid ? "Get Paktly" : "Contact support"}</Link>
        </div>
        <small>Review the plan before joining. A Paktly invitation never asks for a seed phrase or payment.</small>
      </div>
    </section>
  );
}
