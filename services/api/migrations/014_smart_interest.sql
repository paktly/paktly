CREATE TABLE smart_interest (
  user_id uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  interested boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
