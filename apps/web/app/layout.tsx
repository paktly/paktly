import type { Metadata } from "next";
import type { ReactNode } from "react";
import { SiteFooter } from "../components/site-footer";
import { SiteHeader } from "../components/site-header";
import "./styles.css";

export const metadata: Metadata = {
  metadataBase: new URL(process.env.NEXT_PUBLIC_SITE_URL ?? "https://paktly.io"),
  title: "Paktly — Plan together. Fund together. Make it happen.",
  description:
    "Plan shared goals, pool money, split expenses, and settle up for trips, events, celebrations, households, and everything you do together.",
  alternates: { canonical: "/" },
  openGraph: { type: "website", title: "Paktly — Plan together. Fund together. Make it happen.", description: "One place for shared plans, shared goals, and shared money.", url: "/", siteName: "Paktly" },
  twitter: { card: "summary_large_image", title: "Paktly — Plan together. Fund together. Make it happen.", description: "One place for shared plans, shared goals, and shared money." },
  icons: { icon: "/icon.svg", apple: "/apple-icon.png" },
  manifest: "/manifest.webmanifest"
};

export default function RootLayout({ children }: Readonly<{ children: ReactNode }>) {
  return (
    <html lang="en">
      <body><a className="skip-link" href="#main-content">Skip to content</a><SiteHeader /><main id="main-content">{children}</main><SiteFooter /></body>
    </html>
  );
}
