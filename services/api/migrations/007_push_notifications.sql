ALTER TABLE notifications
  ADD COLUMN category TEXT NOT NULL DEFAULT 'ACTIVITY',
  ADD COLUMN data JSONB NOT NULL DEFAULT '{}',
  ADD COLUMN deep_link TEXT,
  ADD COLUMN deduplication_key TEXT,
  ADD COLUMN priority TEXT NOT NULL DEFAULT 'NORMAL' CHECK (priority IN ('NORMAL','HIGH')),
  ADD COLUMN expires_at TIMESTAMPTZ;

CREATE UNIQUE INDEX notifications_user_deduplication
  ON notifications(user_id,deduplication_key)
  WHERE deduplication_key IS NOT NULL;

CREATE TABLE push_devices (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  installation_id UUID NOT NULL,
  platform TEXT NOT NULL CHECK(platform='IOS'),
  apns_token TEXT NOT NULL CHECK(length(apns_token) BETWEEN 32 AND 512),
  apns_environment TEXT NOT NULL CHECK(apns_environment IN ('SANDBOX','PRODUCTION')),
  bundle_id TEXT NOT NULL,
  locale TEXT NOT NULL DEFAULT 'en',
  timezone TEXT NOT NULL DEFAULT 'UTC',
  app_version TEXT,
  device_model TEXT,
  status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK(status IN ('ACTIVE','INACTIVE','INVALID')),
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  invalidated_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(installation_id),
  UNIQUE(apns_token,apns_environment,bundle_id)
);
CREATE INDEX push_devices_user_active ON push_devices(user_id,status);

CREATE TABLE notification_preferences (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  invitations BOOLEAN NOT NULL DEFAULT true,
  expenses BOOLEAN NOT NULL DEFAULT true,
  settlements BOOLEAN NOT NULL DEFAULT true,
  contributions BOOLEAN NOT NULL DEFAULT true,
  plan_reminders BOOLEAN NOT NULL DEFAULT true,
  marketing BOOLEAN NOT NULL DEFAULT false,
  sound_enabled BOOLEAN NOT NULL DEFAULT true,
  badges_enabled BOOLEAN NOT NULL DEFAULT true,
  lock_screen_detail TEXT NOT NULL DEFAULT 'STANDARD' CHECK(lock_screen_detail IN ('STANDARD','PRIVATE')),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE notification_deliveries (
  id UUID PRIMARY KEY,
  notification_id UUID NOT NULL REFERENCES notifications(id) ON DELETE CASCADE,
  device_id UUID NOT NULL REFERENCES push_devices(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'PENDING' CHECK(status IN ('PENDING','PROCESSING','SUBMITTED','RETRY_PENDING','FAILED','INVALID_TOKEN','SUPPRESSED')),
  attempts INTEGER NOT NULL DEFAULT 0 CHECK(attempts>=0),
  available_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  locked_at TIMESTAMPTZ,
  submitted_at TIMESTAMPTZ,
  apns_id TEXT,
  last_error TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(notification_id,device_id)
);
CREATE INDEX notification_deliveries_ready
  ON notification_deliveries(status,available_at)
  WHERE status IN ('PENDING','RETRY_PENDING','PROCESSING');

CREATE OR REPLACE FUNCTION enqueue_notification_deliveries() RETURNS trigger AS $$
BEGIN
  INSERT INTO notification_deliveries(id,notification_id,device_id)
  SELECT gen_random_uuid(),NEW.id,d.id
  FROM push_devices d
  WHERE d.user_id=NEW.user_id AND d.status='ACTIVE'
  ON CONFLICT(notification_id,device_id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER notifications_enqueue_push
AFTER INSERT ON notifications
FOR EACH ROW EXECUTE FUNCTION enqueue_notification_deliveries();
