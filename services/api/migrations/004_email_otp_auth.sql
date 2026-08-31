CREATE TABLE email_otp_challenges (
  id UUID PRIMARY KEY,
  email TEXT NOT NULL CHECK (email = lower(email)),
  code_hash CHAR(64) NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  attempts INTEGER NOT NULL DEFAULT 0 CHECK (attempts BETWEEN 0 AND 5),
  consumed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX email_otp_challenges_lookup
  ON email_otp_challenges(email, created_at DESC);

CREATE INDEX email_otp_challenges_expiry
  ON email_otp_challenges(expires_at)
  WHERE consumed_at IS NULL;

