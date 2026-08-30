import { createHash, randomUUID } from "node:crypto";
import postgres from "postgres";
import { NextResponse, type NextRequest } from "next/server";
import { parseWaitlistRequest } from "../../../lib/waitlist";

const POLICY_VERSION = "2026-08-27";
const WINDOW_MS = 15 * 60 * 1_000;
const MAX_REQUESTS = 10;
const attempts = new Map<string, { count: number; expiresAt: number }>();

function isRateLimited(request: NextRequest): boolean {
  const forwarded = request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "unknown";
  const key = createHash("sha256").update(forwarded).digest("hex");
  const now = Date.now();
  const current = attempts.get(key);
  if (!current || current.expiresAt <= now) {
    attempts.set(key, { count: 1, expiresAt: now + WINDOW_MS });
    return false;
  }
  current.count += 1;
  return current.count > MAX_REQUESTS;
}

export async function POST(request: NextRequest) {
  if (isRateLimited(request)) {
    return NextResponse.json({ message: "Too many attempts. Please try again later." }, { status: 429 });
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ message: "Please submit a valid request." }, { status: 400 });
  }

  const parsed = parseWaitlistRequest(body);
  if (!parsed.success) {
    return NextResponse.json({ message: "Enter a valid email, confirm consent, and acknowledge the terms." }, { status: 400 });
  }

  // A filled hidden field indicates a likely automated submission. Return a generic
  // success response so bots do not learn which protection rejected them.
  if (parsed.data.company.length > 0) {
    return NextResponse.json({ message: "Request accepted." }, { status: 202 });
  }

  const databaseUrl = process.env.DATABASE_URL;
  if (!databaseUrl) {
    return NextResponse.json({ message: "Waitlist storage is temporarily unavailable." }, { status: 503 });
  }

  const sql = postgres(databaseUrl, { idle_timeout: 10, max: 2, prepare: false });
  try {
    await sql`
      INSERT INTO waitlist_signups (
        id, email, marketing_consent, consent_policy_version, terms_version, consented_at, source
      ) VALUES (
        ${randomUUID()}, ${parsed.data.email}, TRUE, ${POLICY_VERSION}, ${POLICY_VERSION}, NOW(), 'website'
      )
      ON CONFLICT (email) DO UPDATE SET
        marketing_consent = TRUE,
        consent_policy_version = EXCLUDED.consent_policy_version,
        terms_version = EXCLUDED.terms_version,
        consented_at = NOW(),
        unsubscribed_at = NULL,
        updated_at = NOW()
    `;
    return NextResponse.json({ message: "Request accepted." }, { status: 201 });
  } catch {
    return NextResponse.json({ message: "Waitlist storage is temporarily unavailable." }, { status: 503 });
  } finally {
    await sql.end();
  }
}
