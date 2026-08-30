import Link from "next/link";
import { BrandMark } from "./brand-mark";

export function SiteHeader() {
  return (
    <header className="site-header">
      <nav className="nav container" aria-label="Primary navigation">
        <Link href="/" className="brand-link"><BrandMark /></Link>
        <div className="nav-links">
          <Link href="/#how-it-works">How it works</Link>
          <Link href="/features">Features</Link>
          <Link href="/security">Security</Link>
          <Link href="/faq">FAQ</Link>
          <Link href="/#waitlist" className="nav-cta">Join the waitlist</Link>
        </div>
      </nav>
    </header>
  );
}
