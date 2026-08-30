CREATE TABLE auth_identities (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id),
  provider TEXT NOT NULL CHECK (provider IN ('SOCKETFI')),
  provider_subject TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(provider, provider_subject)
);

CREATE TABLE wallet_addresses (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id),
  provider TEXT NOT NULL CHECK (provider IN ('SOCKETFI')),
  network TEXT NOT NULL CHECK (network IN ('TESTNET','PUBLIC')),
  address TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(provider, network, address),
  UNIQUE(user_id, provider, network)
);

CREATE INDEX auth_identities_user ON auth_identities(user_id);
CREATE INDEX wallet_addresses_user ON wallet_addresses(user_id);
