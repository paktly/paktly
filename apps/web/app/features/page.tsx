import type { Metadata } from "next";
import Link from "next/link";
import { PageHero } from "../../components/page-hero";

export const metadata: Metadata = { title: "Features | Paktly", description: "Plan, budget, fund, spend, split, reconcile, and settle anything your group does together.", alternates: { canonical: "/features" } };

const stages = [
  ["Plan", "Dates, ideas, tasks, notes, documents, and people stay connected to one private shared plan."],
  ["Budget", "Set a total and category targets, compare plans with actual spending, and see remaining or overspent amounts."],
  ["Save", "Choose a group goal and personal contribution rhythm while preserving each member’s beneficial contribution claim."],
  ["Spend", "Future provider-backed group spending can apply shared limits and create a transaction record automatically."],
  ["Split", "Use equal, exact, percentage, shares, or itemized splits without putting ordinary expense details on-chain."],
  ["Reconcile", "Immutable accounting records produce clear balances while debt simplification recommends fewer settlement paths."],
  ["Settle", "Record external payments or, where legally and technically available, settle from eligible group funds."],
  ["Return", "Unused future group funds follow documented contribution ownership and group-approved refund rules."]
] as const;

export default function FeaturesPage() {
  return <><PageHero eyebrow="THE COMPLETE SHARED-MONEY FLOW" title="One plan. Every money moment." description="From a weekend away to a wedding, shared home, community event, or group purchase, Paktly replaces disconnected notes, spreadsheets, reminders, and awkward final math." /><section className="container feature-catalog">{stages.map(([title, description], index) => <article key={title}><span>0{index + 1}</span><div><h2>{title}</h2><p>{description}</p></div></article>)}</section><section className="feature-boundary container"><div><h2>Available-first foundation</h2><p>The first consumer release prioritizes shared plans, budgets, expenses, splits, balances, and settlement records without holding money. Travel is the first polished workflow, not the product ceiling.</p></div><div><h2>Controlled future features</h2><p>USDC group funding, programmable vaults, fiat funding, and card spending remain testnet or provider-sandbox features until legal, partner, security, and reconciliation gates are satisfied.</p></div></section><section className="center-cta container"><h2>Help shape the first shared plans.</h2><Link className="button primary" href="/#waitlist">Join the waitlist <span>→</span></Link></section></>;
}
