import type { ReactNode } from "react";

type PageHeroProps = { eyebrow: string; title: string; description: string; children?: ReactNode };

export function PageHero({ eyebrow, title, description, children }: PageHeroProps) {
  return <section className="page-hero container"><span className="section-kicker">{eyebrow}</span><h1>{title}</h1><p>{description}</p>{children}</section>;
}
