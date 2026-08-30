import type { Metadata } from "next";
import Link from "next/link";
import { PageHero } from "../../components/page-hero";

export const metadata: Metadata = { title: "Download | Paktly", description: "Paktly iOS availability and early access.", alternates: { canonical: "/download" } };

export default function DownloadPage() { return <><PageHero eyebrow="iOS FIRST" title="Not in the App Store yet." description="Paktly is still in development. There is no public App Store or TestFlight build to download today, and we will never send an installation link that asks for a seed phrase or payment." /><section className="container download-panel"><div className="download-icon" aria-hidden="true">P</div><div><span className="status-chip planned">PRELAUNCH</span><h2>Get the legitimate link when it exists.</h2><p>Early-access invitations will identify the official developer, supported iOS version, privacy details, and TestFlight or App Store destination before installation.</p><Link className="button primary" href="/#waitlist">Join the waitlist <span>→</span></Link></div></section><section className="container notice-panel"><h2>Avoid impersonators</h2><p>Paktly does not currently distribute an iOS application publicly. Do not install profiles, enter wallet recovery phrases, transfer USDC, or pay for access based on an unsolicited message claiming otherwise.</p></section></>; }
