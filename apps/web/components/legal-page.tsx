import type { ReactNode } from "react";
import { PageHero } from "./page-hero";

type LegalSection = { title: string; content: ReactNode };
type LegalPageProps = { eyebrow: string; title: string; summary: string; effectiveDate: string; sections: readonly LegalSection[] };

export function LegalPage({ eyebrow, title, summary, effectiveDate, sections }: LegalPageProps) {
  return <><PageHero eyebrow={eyebrow} title={title} description={summary}><p className="effective-date">Effective {effectiveDate}</p></PageHero><article className="legal-layout container"><nav aria-label={`${title} sections`} className="legal-index"><strong>On this page</strong>{sections.map((section, index) => <a key={section.title} href={`#section-${index + 1}`}>{section.title}</a>)}</nav><div className="legal-content">{sections.map((section, index) => <section id={`section-${index + 1}`} key={section.title}><h2>{section.title}</h2>{section.content}</section>)}</div></article></>;
}
