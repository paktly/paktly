import { existsSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

const publicRoutes = ["/", "/acceptable-use", "/accessibility", "/availability", "/contact", "/cookies", "/download", "/faq", "/features", "/financial-disclosures", "/pricing", "/privacy", "/security", "/support", "/terms"] as const;

describe("public website routes", () => {
  it.each(publicRoutes)("has a page for %s", (route) => {
    const relativePage = route === "/" ? "app/page.tsx" : `app${route}/page.tsx`;
    expect(existsSync(join(process.cwd(), relativePage))).toBe(true);
  });
});
