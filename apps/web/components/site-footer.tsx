import Link from "next/link";
import { BrandMark } from "./brand-mark";

const footerGroups = [
  { title: "Product", links: [["Features", "/features"], ["Pricing", "/pricing"], ["Availability", "/availability"], ["Download", "/download"], ["FAQ", "/faq"]] },
  { title: "Trust", links: [["Security", "/security"], ["Privacy", "/privacy"], ["Accessibility", "/accessibility"], ["Financial disclosures", "/financial-disclosures"], ["Support", "/support"]] },
  { title: "Legal", links: [["Terms", "/terms"], ["Acceptable Use", "/acceptable-use"], ["Cookie Policy", "/cookies"], ["Contact", "/contact"]] }
] as const;

export function SiteFooter() {
  return (
    <footer className="site-footer">
      <div className="container footer-grid">
        <div className="footer-brand">
          <BrandMark />
          <p>Shared plans. Shared goals. Shared money—made simple.</p>
          <p className="footer-note">Paktly is in development and is not currently offering stored-value, card, or money-transmission services.</p>
        </div>
        {footerGroups.map((group) => (
          <div key={group.title} className="footer-group">
            <h2>{group.title}</h2>
            {group.links.map(([label, href]) => <Link key={href} href={href}>{label}</Link>)}
          </div>
        ))}
      </div>
      <div className="container footer-bottom">
        <p>© 2026 Paktly. All rights reserved.</p>
        <p>Prelaunch preview · No real-money services available</p>
      </div>
    </footer>
  );
}
