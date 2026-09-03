CREATE TABLE assistant_usage_daily (
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  usage_date date NOT NULL DEFAULT current_date,
  interpretations integer NOT NULL DEFAULT 0 CHECK (interpretations >= 0),
  transcription_sessions integer NOT NULL DEFAULT 0 CHECK (transcription_sessions >= 0),
  audio_bytes bigint NOT NULL DEFAULT 0 CHECK (audio_bytes >= 0),
  PRIMARY KEY (user_id, usage_date)
);
