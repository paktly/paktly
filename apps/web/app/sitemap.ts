import type { MetadataRoute } from "next";

const routes = ["", "/features", "/pricing", "/availability", "/download", "/faq", "/security", "/support", "/contact", "/privacy", "/terms", "/cookies", "/acceptable-use", "/accessibility", "/financial-disclosures"] as const;

export default function sitemap(): MetadataRoute.Sitemap {
  const siteUrl = process.env.NEXT_PUBLIC_SITE_URL ?? "https://paktly.io";
  return routes.map((route) => ({ url: `${siteUrl}${route}`, lastModified: new Date("2026-08-27"), changeFrequency: route === "" ? "weekly" : "monthly", priority: route === "" ? 1 : 0.7 }));
}
