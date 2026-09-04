CREATE TABLE savings_contributions (
  id UUID PRIMARY KEY,
  group_id UUID NOT NULL REFERENCES groups(id),
  user_id UUID NOT NULL REFERENCES users(id),
  amount_minor BIGINT NOT NULL CHECK (amount_minor > 0),
  currency CHAR(3) NOT NULL,
  source TEXT NOT NULL DEFAULT 'TRACKED_EXTERNAL' CHECK (source = 'TRACKED_EXTERNAL'),
  note TEXT,
  client_operation_id UUID NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, client_operation_id)
);

CREATE INDEX savings_contributions_group_created
  ON savings_contributions(group_id, created_at DESC);
