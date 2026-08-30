CREATE TABLE IF NOT EXISTS waitlist_signups (
  id UUID PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  marketing_consent BOOLEAN NOT NULL CHECK (marketing_consent),
  consent_policy_version TEXT NOT NULL,
  terms_version TEXT NOT NULL,
  consented_at TIMESTAMPTZ NOT NULL,
  source TEXT NOT NULL CHECK (source = 'website'),
  unsubscribed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT waitlist_email_normalized CHECK (email = LOWER(BTRIM(email)))
);

ALTER TABLE waitlist_signups ADD COLUMN IF NOT EXISTS terms_version TEXT;
UPDATE waitlist_signups SET terms_version = consent_policy_version WHERE terms_version IS NULL;
ALTER TABLE waitlist_signups ALTER COLUMN terms_version SET NOT NULL;

COMMENT ON TABLE waitlist_signups IS 'Consent records for the public prelaunch waitlist; no trip or financial data.';
