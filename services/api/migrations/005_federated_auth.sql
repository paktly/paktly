ALTER TABLE auth_identities
  DROP CONSTRAINT IF EXISTS auth_identities_provider_check;

ALTER TABLE auth_identities
  ADD CONSTRAINT auth_identities_provider_check
  CHECK (provider IN ('SOCKETFI','APPLE','GOOGLE'));

CREATE TABLE federated_auth_assertions (
  id UUID PRIMARY KEY,
  provider TEXT NOT NULL CHECK (provider IN ('APPLE','GOOGLE')),
  assertion_hash CHAR(64) NOT NULL UNIQUE,
  expires_at TIMESTAMPTZ NOT NULL,
  consumed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX federated_auth_assertions_expiry
  ON federated_auth_assertions(expires_at);
