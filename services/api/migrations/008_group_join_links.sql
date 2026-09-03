CREATE TABLE group_join_links (
  id UUID PRIMARY KEY,
  group_id UUID NOT NULL REFERENCES groups(id),
  created_by UUID NOT NULL REFERENCES users(id),
  token_hash CHAR(64) NOT NULL UNIQUE,
  code_hash CHAR(64) NOT NULL UNIQUE,
  status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','REVOKED','EXPIRED')),
  max_uses INTEGER NOT NULL DEFAULT 50 CHECK (max_uses BETWEEN 1 AND 500),
  use_count INTEGER NOT NULL DEFAULT 0 CHECK (use_count >= 0),
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  revoked_at TIMESTAMPTZ
);

CREATE UNIQUE INDEX group_join_links_one_active
  ON group_join_links(group_id)
  WHERE status='ACTIVE';

CREATE INDEX group_join_links_active_expiry
  ON group_join_links(expires_at)
  WHERE status='ACTIVE';
