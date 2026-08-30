import Link from "next/link";

export default function NotFound() {
  return <section className="error-page container"><span className="section-kicker">404 · WRONG TURN</span><h1>This wasn’t part of the plan.</h1><p>The page may have moved, or the link may be incomplete.</p><div><Link className="button primary" href="/">Back home <span>→</span></Link><Link href="/support">Visit support</Link></div></section>;
}
