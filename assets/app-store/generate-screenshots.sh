#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INPUT="$ROOT/screenshots"
OUT="$ROOT/assets/app-store/iphone-6.9"
OUT_65="$ROOT/assets/app-store/iphone-6.5"
SOURCE="$ROOT/assets/app-store/source"
BACKGROUND="$SOURCE/paktly-background.png"

if [[ -x "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" ]]; then
  CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
else
  CHROME="${CHROME:-/usr/bin/google-chrome}"
fi

mkdir -p "$OUT" "$OUT_65" "$SOURCE"

encode() { base64 < "$1" | tr -d '\n'; }

render() {
  local key="$1" capture="$2" wash="$3" eyebrow="$4" line_one="$5" line_two="$6" body_one="$7" body_two="$8"
  local screen_data background_data svg html png
  screen_data="$(encode "$INPUT/$capture")"
  background_data="$(encode "$BACKGROUND")"
  svg="$SOURCE/$key.svg"
  html="${TMPDIR:-/tmp}/paktly-app-store-$key.html"
  png="$OUT/$key.png"

  cat > "$svg" <<EOF
<svg xmlns="http://www.w3.org/2000/svg" width="1290" height="2796" viewBox="0 0 1290 2796">
  <defs>
    <clipPath id="screen"><rect x="195" y="800" width="900" height="1948" rx="55"/></clipPath>
    <filter id="shadow" x="-30%" y="-20%" width="160%" height="160%">
      <feDropShadow dx="0" dy="34" stdDeviation="38" flood-color="#10261D" flood-opacity="0.20"/>
    </filter>
    <linearGradient id="glow" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="$wash" stop-opacity="0.38"/>
      <stop offset="1" stop-color="$wash" stop-opacity="0"/>
    </linearGradient>
  </defs>

  <image width="1290" height="2796" preserveAspectRatio="xMidYMid slice" href="data:image/png;base64,$background_data"/>
  <rect width="1290" height="2796" fill="#FBF8F0" opacity="0.83"/>
  <circle cx="1160" cy="120" r="320" fill="url(#glow)"/>
  <circle cx="30" cy="690" r="210" fill="$wash" opacity="0.12"/>

  <g transform="translate(82 72)">
    <g transform="scale(.5)">
      <path d="M43 33C59 16 88 22 96 49" fill="none" stroke="#214C3A" stroke-width="25" stroke-linecap="round"/>
      <path d="M96 70C89 96 59 107 38 90" fill="none" stroke="#FF816F" stroke-width="25" stroke-linecap="round"/>
      <path d="M31 105V83C18 61 29 35 51 28" fill="none" stroke="#3F9D6D" stroke-width="25" stroke-linecap="round" stroke-linejoin="round"/>
    </g>
    <text x="84" y="47" fill="#10261D" font-family="-apple-system, BlinkMacSystemFont, 'Helvetica Neue', Arial, sans-serif" font-size="40" font-weight="750" letter-spacing="-1">paktly</text>
  </g>

  <text x="84" y="246" fill="#1E5A45" font-family="-apple-system, BlinkMacSystemFont, 'Helvetica Neue', Arial, sans-serif" font-size="23" font-weight="750" letter-spacing="4">$eyebrow</text>
  <text x="80" y="376" fill="#10261D" font-family="-apple-system, BlinkMacSystemFont, 'Helvetica Neue', Arial, sans-serif" font-size="88" font-weight="760" letter-spacing="-3">
    <tspan x="80" dy="0">$line_one</tspan>
    <tspan x="80" dy="98">$line_two</tspan>
  </text>
  <text x="84" y="610" fill="#536861" font-family="-apple-system, BlinkMacSystemFont, 'Helvetica Neue', Arial, sans-serif" font-size="32" font-weight="450">
    <tspan x="84" dy="0">$body_one</tspan>
    <tspan x="84" dy="45">$body_two</tspan>
  </text>

  <g filter="url(#shadow)">
    <rect x="171" y="776" width="948" height="1996" rx="78" fill="#0A1712"/>
    <image x="195" y="800" width="900" height="1948" preserveAspectRatio="xMidYMid slice" clip-path="url(#screen)" href="data:image/png;base64,$screen_data"/>
  </g>
</svg>
EOF

  cat > "$html" <<EOF
<!doctype html><html><head><meta charset="utf-8"><style>html,body{margin:0;width:1290px;height:2796px;overflow:hidden}svg{display:block}</style></head><body>$(cat "$svg")</body></html>
EOF

  "$CHROME" --headless=new --disable-gpu --no-sandbox --disable-dev-shm-usage \
    --user-data-dir="${TMPDIR:-/tmp}/paktly-store-chrome-$key" --hide-scrollbars \
    --force-device-scale-factor=1 --window-size=1290,2796 --screenshot="$png" "file://$html" >/dev/null 2>&1
  ffmpeg -loglevel error -y -i "$png" -vf "scale=1284:2778:flags=lanczos,format=rgb24" "$OUT_65/$key.png"
  rm -f "$html"
}

render "01-plan-together" "IMG_1206.png" "#B6EED1" "SHARED PLANS · SHARED MONEY" \
  "Plan together." "Settle with clarity." \
  "See active plans, shared balances, and what needs" "your attention—all in one calm place."

render "02-every-kind-of-plan" "IMG_1207.png" "#DCD3FF" "MORE THAN TRIPS" \
  "Every shared plan." "One place." \
  "Organize trips, homes, celebrations, events," "projects, and the goals you share."

render "03-add-your-way" "IMG_1209.png" "#B6EED1" "LESS TYPING · MORE DOING" \
  "Add it your way." "Paktly keeps up." \
  "Speak naturally, scan a receipt, record an expense," "or invite someone in seconds."

render "04-scan-receipts" "IMG_1211.png" "#DCD3FF" "RECEIPTS, WITHOUT THE BUSYWORK" \
  "Scan it. Review it." "Split it." \
  "Capture the merchant, total, and currency—then" "confirm the payer and split before saving."

render "05-flexible-plans" "IMG_1212.png" "#FFB6AA" "BUILT AROUND REAL LIFE" \
  "A plan for whatever" "you’re doing together." \
  "Start a trip, household, celebration, event," "project, savings goal, or custom plan."

render "06-invite-everyone" "IMG_1214.png" "#B6EED1" "BRING YOUR PEOPLE" \
  "Invite now." "Add anyone later." \
  "Use a username, email, shareable link, or join code" "to bring the right people into every plan."

render "07-multiple-currencies" "IMG_1213.png" "#DCD3FF" "MONEY THAT FITS THE PLAN" \
  "Choose the currency" "that works for you." \
  "Set a primary plan currency while keeping room" "for expenses recorded in other currencies."

render "08-clear-balances" "IMG_1216.png" "#FFB6AA" "KNOW WHERE EVERYONE STANDS" \
  "Who owes what." "Clear at a glance." \
  "Understand balances across plans and settle up" "without losing the underlying history."

cp "$ROOT/apps/ios/Paktly/Assets.xcassets/AppIcon.appiconset/Paktly-AppIcon-1024.png" "$ROOT/assets/app-store/icon-1024.png"
printf 'Created Paktly App Store media in %s and %s\n' "$OUT" "$OUT_65"
