import type { Metadata } from "next";
import { LegalPage } from "../../components/legal-page";

export const metadata: Metadata = { title: "Acceptable Use Policy | Paktly", description: "Rules protecting Paktly visitors, systems, and future financial services from abuse.", alternates: { canonical: "/acceptable-use" } };

const sections = [
  { title: "Use the service lawfully", content: <p>You may not use Paktly to violate law, regulation, sanctions, court orders, or another person’s rights; facilitate fraud, theft, money laundering, terrorist financing, trafficking, or evasion; or misrepresent your identity, authority, age, location, or relationship to another person.</p> },
  { title: "Protect people and groups", content: <p>Do not harass, threaten, exploit, impersonate, or expose another participant; publish private plans, location, contact, payment, or identity information without authority; create deceptive invitations; or use group features to coerce payments or manipulate approvals.</p> },
  { title: "Protect accounts and systems", content: <p>Do not probe or bypass security, scrape at unreasonable volume, distribute malware, automate fraudulent submissions, replay credentials or webhooks, interfere with service availability, access another account, or attempt to extract passkey secrets, private keys, provider credentials, or nonpublic data.</p> },
  { title: "Future financial restrictions", content: <p>If financial features launch, prohibited activity will also include unauthorized payments, transaction laundering, sanctions evasion, unsupported gambling or cash-equivalent activity, abusive chargebacks, card testing, destination-address manipulation, and attempts to bypass spending, cancellation, refund, KYC, or group-authorization controls.</p> },
  { title: "Enforcement", content: <p>We may block requests, remove content, restrict access, preserve evidence, or report suspected unlawful conduct where appropriate. We will design financial-feature enforcement with documented review and appeal paths where required. Enforcement does not create a duty to monitor every submission.</p> },
  { title: "Report abuse", content: <p>Report suspected abuse to <a href="mailto:abuse@paktly.io">abuse@paktly.io</a>. Security vulnerabilities should be reported through the process on our <a href="/security">Security page</a>, not tested against production users or data.</p> }
] as const;

export default function AcceptableUsePage() { return <LegalPage eyebrow="KEEP THE GROUP SAFE" title="Acceptable Use Policy" summary="Boundaries that protect participants, the service, and any future financial infrastructure." effectiveDate="August 27, 2026" sections={sections} />; }
