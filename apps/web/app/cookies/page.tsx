import type { Metadata } from "next";
import { LegalPage } from "../../components/legal-page";

export const metadata: Metadata = { title: "Cookie Policy | Paktly", description: "Cookies and similar technologies used by the Paktly prelaunch website.", alternates: { canonical: "/cookies" } };

const sections = [
  { title: "Current cookie use", content: <p>The current Paktly prelaunch website does not intentionally set advertising, cross-site tracking, personalization, or session-replay cookies. The public pages do not require an account cookie. Our hosting or security infrastructure may use strictly necessary technical mechanisms to route requests, balance traffic, prevent abuse, or preserve security.</p> },
  { title: "Analytics", content: <p>We have not enabled optional behavioral analytics in this repository. Before enabling nonessential analytics or session replay, we will update this policy, identify the provider and retention period, and display consent controls where required. Declining optional analytics will not prevent access to public content.</p> },
  { title: "Local storage and similar technology", content: <p>The waitlist form does not intentionally store marketing identifiers in your browser. Browser, network, or hosting technology may cache public resources to improve performance. These mechanisms are not used by Paktly to build an advertising profile.</p> },
  { title: "Your controls", content: <p>You can block or delete cookies through browser settings. Blocking strictly necessary technology may affect security or availability. If optional categories are introduced, this page will provide a direct way to revisit your choices.</p> },
  { title: "Changes and contact", content: <p>We will revise this policy before introducing materially different tracking practices. Questions can be sent to <a href="mailto:privacy@paktly.io">privacy@paktly.io</a>.</p> }
] as const;

export default function CookiesPage() { return <LegalPage eyebrow="TRACKING CHOICES" title="Cookie Policy" summary="The short version: this prelaunch site currently avoids nonessential tracking cookies." effectiveDate="August 27, 2026" sections={sections} />; }
