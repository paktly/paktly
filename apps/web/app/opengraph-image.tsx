import { ImageResponse } from "next/og";

export const alt = "Paktly — Plan together. Fund together. Make it happen.";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

export default function OpenGraphImage() {
  return new ImageResponse(<div style={{ width: "100%", height: "100%", display: "flex", alignItems: "center", justifyContent: "space-between", padding: 80, color: "#18251f", background: "#f8f5ed", fontFamily: "sans-serif" }}><div style={{ display: "flex", flexDirection: "column", maxWidth: 780 }}><div style={{ display: "flex", alignItems: "center", gap: 18, fontSize: 32, fontWeight: 800 }}><div style={{ display: "flex", width: 58, height: 58, alignItems: "center", justifyContent: "center", borderRadius: "20px 20px 20px 7px", color: "#bff1d3", background: "#18251f" }}>P</div>Paktly</div><div style={{ display: "flex", marginTop: 64, fontSize: 68, fontWeight: 700, lineHeight: 1.02, letterSpacing: -4 }}>Plan together.<br />Fund together.<br />Make it happen.</div><div style={{ display: "flex", marginTop: 38, color: "#56625c", fontSize: 26 }}>Shared plans. Shared goals. Shared money.</div></div><div style={{ display: "flex", width: 280, height: 420, alignItems: "center", justifyContent: "center", border: "10px solid #18251f", borderRadius: 46, background: "#bff1d3", boxShadow: "0 30px 80px rgba(33,76,58,.2)", fontSize: 120, fontWeight: 700 }}>+</div></div>, size);
}
