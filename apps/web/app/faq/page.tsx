import type { Metadata } from "next";
import { Accordion } from "../../components/accordion";
import { PageHero } from "../../components/page-hero";

export const metadata: Metadata = { title: "FAQ | Paktly", description: "Answers about Paktly, expense sharing, group savings, security, and prelaunch availability.", alternates: { canonical: "/faq" } };

const questions = [
  ["What is Paktly?", "Paktly is an iOS-first product for shared plans and shared money: plan, budget, fund, spend, split, reconcile, and settle together. Travel is the first deep use case, alongside events, celebrations, households, group purchases, and collective goals."],
  ["Can I use it today?", "Not yet. This website is a product preview and waitlist. No consumer account or financial service is currently available."],
  ["Is Paktly a bank, wallet, card issuer, or money transmitter?", "No. Paktly is not currently providing those services. Future regulated capabilities would rely on approved partners and launch only with provider-specific disclosures."],
  ["Does joining cost anything?", "No. Joining the waitlist is free and does not require payment information."],
  ["Is every expense put on a blockchain?", "No. Ordinary expenses, splits, receipts, and balances are designed to remain in private off-chain accounting. Only actual future stored-value movements may use Stellar."],
  ["Will I need a seed phrase?", "The intended experience is passkey-first, using Face ID or device authentication. Normal onboarding should not expose a seed phrase."],
  ["What role is planned for SocketFi?", "SocketFi is intended to sit behind Paktly’s smart-account interface for account creation and authorization. Its production integration is not yet live or represented by this website."],
  ["How would group funding differ from an expense?", "A contribution remains attributable to the person who supplied it until funds are consumed under agreed group rules. Contributing more does not automatically mean owing less for an unrelated expense."],
  ["Can one person cancel a funded plan?", "The planned default is unanimous active-member approval for cancelling a funded group plan, with deterministic claims-based refunds. This is not yet a live financial feature."],
  ["How will group-card purchases work?", "The planned flow receives a provider transaction, asks who it was for, creates an expense split, and updates balances. Cards are conditional on provider and jurisdiction approval."],
  ["Where will Paktly launch?", "No launch region has been announced. Availability will vary by product capability and regulated provider coverage."],
  ["How can I delete my waitlist information?", "Email privacy@paktly.io from the address you used and request deletion. We may verify control of that address before acting."],
  ["How can I report a security issue?", "Follow the responsible-disclosure instructions on the Security page and avoid accessing other people’s data or disrupting the service."]
] as const;

export default function FAQPage() { return <><PageHero eyebrow="QUESTIONS, ANSWERED" title="Useful answers. No crypto fog." description="What exists now, what is planned, and what still depends on approvals." /><section className="container faq-list"><Accordion items={questions} /></section></>; }
