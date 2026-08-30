import type { Metadata } from "next";
import { PageHero } from "../../components/page-hero";

export const metadata: Metadata = { title: "Security | Paktly", description: "Paktly security architecture, privacy boundaries, and vulnerability reporting.", alternates: { canonical: "/security" } };

const controls = [
  ["Passkey-first access", "The planned default uses platform passkeys and device verification rather than passwords or consumer-managed seed phrases."],
  ["Private expense records", "Group details, receipts, participants, and ordinary splits stay off-chain and are restricted to authorized membership."],
  ["Explicit authority", "Individual, admin, and group-controlled actions have separate permission models. High-risk group actions require member approvals."],
  ["Immutable accounting", "Financial balances are designed around double-entry journal records, idempotent workflows, and reconciliation—not direct balance mutation."],
  ["Provider isolation", "SocketFi, card, funding, CCTP, and wallet capabilities sit behind narrow interfaces so one provider does not own core accounting logic."],
  ["Safe observability", "Structured logs, request IDs, metrics, and audit records are designed to redact credentials, card data, private keys, and KYC documents."]
] as const;

export default function SecurityPage() { return <><PageHero eyebrow="SECURITY" title="Simple for groups. Serious underneath." description="These are architectural commitments for the product under development—not a claim that unreleased financial systems have completed review." /><section className="container security-grid">{controls.map(([title, text]) => <article key={title}><span aria-hidden="true">✓</span><h2>{title}</h2><p>{text}</p></article>)}</section><section className="container disclosure-box"><h2>Responsible vulnerability disclosure</h2><p>Email <a href="mailto:security@paktly.io">security@paktly.io</a> with a description, affected URL or component, reproduction steps, and impact. Do not access another person’s data, move funds, degrade availability, use social engineering, or publish details before we have had a reasonable opportunity to investigate.</p><p>We will acknowledge good-faith reports when operationally possible. This page does not create a bug-bounty promise, safe-harbor agreement, or authorization to test third-party providers.</p></section><section className="container security-boundary"><h2>Before any real money</h2><ul><li>External smart-contract and application security review</li><li>Ledger, refund, idempotency, and reconciliation invariants</li><li>Threat model and incident-response exercises</li><li>Provider webhook, authorization, and outage tests</li><li>Legal, compliance, and operational approval for each region</li></ul></section></>; }
