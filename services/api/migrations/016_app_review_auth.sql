-- Dedicated review accounts must never be confused with ordinary customer accounts.
ALTER TABLE users ADD COLUMN is_app_review BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE email_otp_challenges ADD COLUMN is_app_review BOOLEAN NOT NULL DEFAULT false;
