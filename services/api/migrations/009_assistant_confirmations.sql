CREATE TABLE assistant_action_confirmations (
  draft_id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  idempotency_key varchar(100) NOT NULL,
  draft jsonb NOT NULL,
  confirmed_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, idempotency_key)
);

CREATE INDEX assistant_action_confirmations_user_confirmed_idx
  ON assistant_action_confirmations(user_id, confirmed_at DESC);
