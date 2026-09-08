import type { Metadata } from "next";
import Link from "next/link";
import { PageHero } from "../../components/page-hero";

export const metadata: Metadata = { title: "Support | Paktly", description: "Help with Paktly accounts, shared plans, invitations, expenses, and privacy.", alternates: { canonical: "/support" } };

export default function SupportPage() {
  return <>
    <PageHero eyebrow="SUPPORT" title="How can we help?" description="Get help with your account, shared plans, invitations, and expenses. Never send passwords, one-time codes, private keys, or payment-card details." />
    <section className="container support-grid">
      <a href="mailto:hello@paktly.io?subject=Paktly%20app%20support"><span>01</span><h2>App support</h2><p>Include your app version, device model, and a short description. Redact personal information from screenshots.</p></a>
      <Link href="/account-deletion"><span>02</span><h2>Delete your account</h2><p>Use You → Delete account in the app, or see the options if you cannot sign in.</p></Link>
      <a href="mailto:privacy@paktly.io?subject=Paktly%20privacy%20request"><span>03</span><h2>Privacy request</h2><p>Ask about access, correction, deletion, or your data choices.</p></a>
      <a href="mailto:security@paktly.io?subject=Paktly%20security%20report"><span>04</span><h2>Security report</h2><p>Report a suspected vulnerability without including credentials or other people’s data.</p></a>
    </section>
    <section className="container support-note"><h2>Before you contact us</h2><p>Check your connection and update Paktly. For an invitation, sign in with the invited email. For notifications, check both Paktly preferences and iOS Settings. Before retrying a slow expense request, check whether it was saved.</p><p>Recorded savings and settlements track money outside Paktly; they do not transfer funds. Support is not an emergency service.</p></section>
  </>;
}
