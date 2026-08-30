import Link from "next/link";
import { Accordion } from "../components/accordion";
import { TripPreview } from "../components/trip-preview";
import { WaitlistForm } from "../components/waitlist-form";
import { journeySteps, trustPoints } from "../lib/content";

const featureStories = [
  { eyebrow: "EXPENSES", title: "Split the moment, not the friendship.", text: "Equal, exact, percentage, shares, and itemized splits—with original currencies and an audit-friendly history.", icon: "↔" },
  { eyebrow: "GROUP FUNDING", title: "Turn someday into a shared target.", text: "Set the goal, choose a rhythm, and see how each person and the whole group are progressing.", icon: "↗" },
  { eyebrow: "GROUP BALANCE", title: "One clear view of the money.", text: "Understand what is funded, spent, owed, and refundable without needing to understand the infrastructure underneath.", icon: "◎" },
  { eyebrow: "AUTOMATIC RECONCILIATION", title: "A purchase becomes an expense.", text: "The future Trip Card flow asks who a purchase was for, creates the split, and keeps balances current automatically.", icon: "✓" }
] as const;

const commonQuestions = [
  ["Can I use Paktly today?", "Not yet. This website is a prelaunch product preview and waitlist."],
  ["Is Paktly a bank or card issuer?", "No. Paktly is not currently offering banking, custody, card, or money-transmission services."],
  ["Will I need to understand crypto?", "No. Expense sharing stays off-chain, and future stored-value infrastructure is designed to remain behind familiar product language."]
] as const;

export default function HomePage() {
  return <>
    <section id="top" className="hero container">
      <div className="hero-copy">
        <span className="pill"><span>●</span> Money for the memories</span>
        <h1>Plan together.<br />Fund together.<br /><em>Make it happen.</em></h1>
        <p className="hero-lede">From the first idea to the final split, Paktly gives your group one place for the plan, the goal, and the money behind it.</p>
        <div className="hero-actions"><a href="#waitlist" className="button primary">Get early access <span>→</span></a><a href="#how-it-works" className="text-link">See how it works <span>↓</span></a></div>
        <div className="prelaunch-badge"><strong>Start with any shared plan</strong><span>Trips are one use case—not the boundary. Paktly is designed for events, celebrations, group purchases, households, and collective goals too.</span></div>
      </div>
      <TripPreview />
    </section>

    <section className="use-case-strip" aria-label="Ways to use Paktly"><div className="container"><span>Group trips</span><span>Celebrations</span><span>Events</span><span>Shared homes</span><span>Group purchases</span><span>Community goals</span></div></section>

    <section id="how-it-works" className="journey-section"><div className="container"><span className="section-kicker">ONE SHARED PLAN</span><h2>Less money admin.<br />More happening together.</h2><div className="journey-grid">{journeySteps.map((step, index) => <article key={step.label}><span className="step-number">0{index + 1}</span><h3>{step.label}</h3><p>{step.detail}</p></article>)}</div></div></section>

    <section className="feature-story-section container" aria-labelledby="feature-heading"><div className="section-intro"><span className="section-kicker">THE WHOLE FINANCIAL LOOP</span><h2 id="feature-heading">Built for before, during, and after the plan.</h2></div><div className="feature-story-grid">{featureStories.map((feature) => <article key={feature.eyebrow}><span className="feature-icon" aria-hidden="true">{feature.icon}</span><small>{feature.eyebrow}</small><h3>{feature.title}</h3><p>{feature.text}</p></article>)}</div><Link className="inline-cta" href="/features">Explore every feature <span>→</span></Link></section>

    <section className="card-loop-section"><div className="container card-loop-grid"><div><span className="section-kicker">THE CLOSED LOOP</span><h2>Spend once.<br />Reconcile automatically.</h2><p>When card capabilities become available through approved providers, a real group purchase can flow directly into the shared expense ledger. Choose who it was for; Paktly handles the split.</p><Link href="/financial-disclosures">What “coming later” means →</Link></div><ol aria-label="Automatic purchase reconciliation flow"><li><span>1</span>Group purchase arrives</li><li><span>2</span>Choose who it was for</li><li><span>3</span>Expense and split are created</li><li><span>4</span>Balances update</li></ol></div></section>

    <section id="security" className="trust-section container"><div><span className="section-kicker">TRUST, WITHOUT THE JARGON</span><h2>Your group is social.<br />Your money stays serious.</h2><p>Passkey-first access, private off-chain expense records, and explicit group approvals are the design baseline—not crypto complexity pushed onto people.</p><Link className="inline-cta" href="/security">Read about security <span>→</span></Link></div><ul>{trustPoints.map((point) => <li key={point}><span>✓</span>{point}</li>)}</ul></section>

    <section className="pricing-preview"><div className="container pricing-preview-inner"><div><span className="section-kicker">CLEAR BEFORE YOU COMMIT</span><h2>Free to join the waitlist.<br />Pricing isn’t final yet.</h2></div><div><p>We will publish consumer fees before any paid or money-moving feature launches. There are no charges for joining this prelaunch list.</p><Link href="/pricing">Pricing principles →</Link></div></div></section>

    <section className="faq-preview container"><div><span className="section-kicker">COMMON QUESTIONS</span><h2>A clear answer beats fine print.</h2></div><div><Accordion items={commonQuestions} /><Link href="/faq">Read all questions →</Link></div></section>

    <section id="waitlist" className="cta-section"><div className="container waitlist-layout"><div><span className="section-kicker">YOUR NEXT SHARED PLAN STARTS HERE</span><h2>Make the plan.<br />Then make it happen.</h2><p>Join for occasional product updates and early-access invitations. No payment information required.</p></div><WaitlistForm /></div></section>
  </>;
}
