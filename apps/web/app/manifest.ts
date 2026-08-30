import type { MetadataRoute } from "next";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "Paktly",
    short_name: "Paktly",
    description: "Plan, fund, spend, split, and settle anything you do together.",
    start_url: "/",
    display: "standalone",
    background_color: "#F8F5ED",
    theme_color: "#214C3A",
    icons: [{ src: "/icon.svg", sizes: "any", type: "image/svg+xml" }]
  };
}
