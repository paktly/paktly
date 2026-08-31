import { ImageResponse } from "next/og";

export const alt = "Paktly — Plan together. Fund together. Make it happen.";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

function Mark({ size: markSize }: { size: number }) {
  return <svg width={markSize} height={markSize} viewBox="0 0 128 128">
    <path d="M43 33C59 16 88 22 96 49" fill="none" stroke="#214C3A" strokeWidth="25" strokeLinecap="round" />
    <path d="M96 70C89 96 59 107 38 90" fill="none" stroke="#FF816F" strokeWidth="25" strokeLinecap="round" />
    <path d="M31 105V83C18 61 29 35 51 28" fill="none" stroke="#BFF1D3" strokeWidth="25" strokeLinecap="round" strokeLinejoin="round" />
  </svg>;
}

export default function OpenGraphImage() {
  return new ImageResponse(
    <div style={{ width: "100%", height: "100%", display: "flex", alignItems: "center", justifyContent: "space-between", padding: 80, color: "#18251f", background: "#f8f5ed", fontFamily: "sans-serif" }}>
      <div style={{ display: "flex", flexDirection: "column", maxWidth: 780 }}>
        <div style={{ display: "flex", alignItems: "center", gap: 16, fontSize: 32, fontWeight: 800 }}>
          <Mark size={62} />Paktly
        </div>
        <div style={{ display: "flex", marginTop: 64, fontSize: 68, fontWeight: 700, lineHeight: 1.02, letterSpacing: -4 }}>Plan together.<br />Fund together.<br />Make it happen.</div>
        <div style={{ display: "flex", marginTop: 38, color: "#56625c", fontSize: 26 }}>Shared plans. Shared goals. Shared money.</div>
      </div>
      <div style={{ display: "flex", width: 300, height: 300, alignItems: "center", justifyContent: "center", border: "1px solid rgba(24,37,31,.12)", borderRadius: 72, background: "#fffdf8", boxShadow: "0 30px 80px rgba(33,76,58,.2)" }}>
        <Mark size={210} />
      </div>
    </div>,
    size
  );
}
