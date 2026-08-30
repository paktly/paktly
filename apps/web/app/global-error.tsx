"use client";

export default function GlobalError({ reset }: { error: Error & { digest?: string }; reset: () => void }) {
  return <html lang="en"><body><main className="error-page container"><span className="section-kicker">SOMETHING WENT WRONG</span><h1>We hit some turbulence.</h1><p>No payment was attempted through this prelaunch website. Try loading the page again.</p><button className="button primary" type="button" onClick={reset}>Try again <span>→</span></button></main></body></html>;
}
