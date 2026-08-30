CREATE TABLE users (
  id UUID PRIMARY KEY,
  email TEXT NOT NULL UNIQUE CHECK (email = lower(email)),
  status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','SUSPENDED','DELETED')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE user_profiles (
  user_id UUID PRIMARY KEY REFERENCES users(id), display_name TEXT NOT NULL,
  username TEXT UNIQUE, avatar_url TEXT, default_currency CHAR(3) NOT NULL DEFAULT 'USD',
  locale TEXT NOT NULL DEFAULT 'en-US', timezone TEXT NOT NULL DEFAULT 'UTC', updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE auth_sessions (
  id UUID PRIMARY KEY, user_id UUID NOT NULL REFERENCES users(id), token_hash CHAR(64) NOT NULL UNIQUE,
  expires_at TIMESTAMPTZ NOT NULL, revoked_at TIMESTAMPTZ, created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE groups (
  id UUID PRIMARY KEY, name TEXT NOT NULL, description TEXT, default_currency CHAR(3) NOT NULL,
  created_by UUID NOT NULL REFERENCES users(id), status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','ARCHIVED')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE group_members (
  group_id UUID NOT NULL REFERENCES groups(id), user_id UUID NOT NULL REFERENCES users(id),
  role TEXT NOT NULL CHECK (role IN ('OWNER','ADMIN','MEMBER')),
  status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','LEFT','REMOVED')),
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(), PRIMARY KEY (group_id,user_id)
);
CREATE TABLE invitations (
  id UUID PRIMARY KEY, group_id UUID NOT NULL REFERENCES groups(id), email TEXT NOT NULL,
  invited_by UUID NOT NULL REFERENCES users(id), token_hash CHAR(64) NOT NULL UNIQUE,
  status TEXT NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING','ACCEPTED','REVOKED','EXPIRED')),
  expires_at TIMESTAMPTZ NOT NULL, accepted_by UUID REFERENCES users(id), accepted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX invitations_one_pending ON invitations(group_id,email) WHERE status='PENDING';
CREATE TABLE expenses (
  id UUID PRIMARY KEY, group_id UUID NOT NULL REFERENCES groups(id), created_by UUID NOT NULL REFERENCES users(id),
  client_operation_id UUID NOT NULL, current_version INTEGER NOT NULL DEFAULT 1,
  status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','DELETED')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(group_id,client_operation_id)
);
CREATE TABLE expense_versions (
  id UUID PRIMARY KEY, expense_id UUID NOT NULL REFERENCES expenses(id), version INTEGER NOT NULL,
  description TEXT NOT NULL, category TEXT NOT NULL, original_amount_minor BIGINT NOT NULL CHECK(original_amount_minor>0),
  original_currency CHAR(3) NOT NULL, converted_amount_minor BIGINT NOT NULL CHECK(converted_amount_minor>0),
  group_currency CHAR(3) NOT NULL, rate_numerator BIGINT NOT NULL CHECK(rate_numerator>0),
  rate_denominator BIGINT NOT NULL CHECK(rate_denominator>0), rate_provider TEXT NOT NULL, rate_timestamp TIMESTAMPTZ NOT NULL,
  paid_by UUID NOT NULL REFERENCES users(id), expense_date TIMESTAMPTZ NOT NULL, notes TEXT,
  split_method TEXT NOT NULL CHECK(split_method IN ('EQUAL','EXACT','PERCENTAGE','SHARES','ITEMIZED')),
  created_by UUID NOT NULL REFERENCES users(id), created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(expense_id,version)
);
CREATE TABLE expense_splits (
  expense_version_id UUID NOT NULL REFERENCES expense_versions(id), user_id UUID NOT NULL REFERENCES users(id),
  original_amount_minor BIGINT NOT NULL CHECK(original_amount_minor>=0), converted_amount_minor BIGINT NOT NULL CHECK(converted_amount_minor>=0),
  PRIMARY KEY(expense_version_id,user_id)
);
CREATE TABLE ledger_accounts (
  id UUID PRIMARY KEY, group_id UUID NOT NULL REFERENCES groups(id), user_id UUID NOT NULL REFERENCES users(id),
  currency CHAR(3) NOT NULL, kind TEXT NOT NULL DEFAULT 'MEMBER_BALANCE' CHECK(kind='MEMBER_BALANCE'),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), UNIQUE(group_id,user_id,currency,kind)
);
CREATE TABLE journal_entries (
  id UUID PRIMARY KEY, group_id UUID NOT NULL REFERENCES groups(id),
  type TEXT NOT NULL CHECK(type IN ('EXPENSE','EXPENSE_REVERSAL','SETTLEMENT')),
  reference_id UUID NOT NULL, reversal_of UUID REFERENCES journal_entries(id), description TEXT NOT NULL,
  created_by UUID NOT NULL REFERENCES users(id), created_at TIMESTAMPTZ NOT NULL DEFAULT now(), UNIQUE(type,reference_id)
);
CREATE TABLE journal_lines (
  id UUID PRIMARY KEY, journal_entry_id UUID NOT NULL REFERENCES journal_entries(id),
  ledger_account_id UUID NOT NULL REFERENCES ledger_accounts(id), debit_minor BIGINT NOT NULL DEFAULT 0,
  credit_minor BIGINT NOT NULL DEFAULT 0,
  CHECK ((debit_minor>0 AND credit_minor=0) OR (credit_minor>0 AND debit_minor=0))
);
CREATE TABLE settlements (
  id UUID PRIMARY KEY, group_id UUID NOT NULL REFERENCES groups(id), from_user_id UUID NOT NULL REFERENCES users(id),
  to_user_id UUID NOT NULL REFERENCES users(id), amount_minor BIGINT NOT NULL CHECK(amount_minor>0), currency CHAR(3) NOT NULL,
  method TEXT NOT NULL CHECK(method IN ('EXTERNAL','CASH','MARKED_PAID')), note TEXT, client_operation_id UUID NOT NULL,
  created_by UUID NOT NULL REFERENCES users(id), created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(group_id,client_operation_id), CHECK(from_user_id<>to_user_id)
);
CREATE TABLE activity_events (
  id UUID PRIMARY KEY, group_id UUID NOT NULL REFERENCES groups(id), actor_user_id UUID REFERENCES users(id),
  type TEXT NOT NULL, entity_type TEXT NOT NULL, entity_id UUID NOT NULL, summary TEXT NOT NULL,
  metadata JSONB NOT NULL DEFAULT '{}', created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE notifications (
  id UUID PRIMARY KEY, user_id UUID NOT NULL REFERENCES users(id), group_id UUID REFERENCES groups(id),
  type TEXT NOT NULL, title TEXT NOT NULL, body TEXT NOT NULL, entity_type TEXT, entity_id UUID,
  read_at TIMESTAMPTZ, created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX group_members_user ON group_members(user_id,status);
CREATE INDEX expenses_group ON expenses(group_id,status,created_at DESC);
CREATE INDEX journal_lines_account ON journal_lines(ledger_account_id);
CREATE INDEX activity_group ON activity_events(group_id,created_at DESC);
CREATE INDEX notifications_user ON notifications(user_id,read_at,created_at DESC);
