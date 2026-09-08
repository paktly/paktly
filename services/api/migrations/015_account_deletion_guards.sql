-- Reject writes from requests that authenticated just before account deletion.
-- The row lock serializes these writes with deletion's users FOR UPDATE lock.
CREATE FUNCTION require_active_account_reference() RETURNS trigger AS $$
DECLARE account_id uuid;
BEGIN
  account_id := (to_jsonb(NEW)->>TG_ARGV[0])::uuid;
  IF account_id IS NULL THEN RETURN NEW; END IF;
  IF TG_TABLE_NAME = 'group_members' AND to_jsonb(NEW)->>'status' <> 'ACTIVE' THEN RETURN NEW; END IF;
  PERFORM id FROM users WHERE id=account_id AND status='ACTIVE' FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Account is not active' USING ERRCODE='23514'; END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER active_account BEFORE INSERT ON auth_sessions FOR EACH ROW EXECUTE FUNCTION require_active_account_reference('user_id');
CREATE TRIGGER active_account BEFORE INSERT ON auth_identities FOR EACH ROW EXECUTE FUNCTION require_active_account_reference('user_id');
CREATE TRIGGER active_account BEFORE INSERT ON wallet_addresses FOR EACH ROW EXECUTE FUNCTION require_active_account_reference('user_id');
CREATE TRIGGER active_account BEFORE INSERT OR UPDATE ON user_profiles FOR EACH ROW EXECUTE FUNCTION require_active_account_reference('user_id');
CREATE TRIGGER active_account BEFORE INSERT OR UPDATE ON friends FOR EACH ROW EXECUTE FUNCTION require_active_account_reference('user_id');
CREATE TRIGGER active_account BEFORE INSERT OR UPDATE ON smart_interest FOR EACH ROW EXECUTE FUNCTION require_active_account_reference('user_id');
CREATE TRIGGER active_account BEFORE INSERT OR UPDATE ON push_devices FOR EACH ROW EXECUTE FUNCTION require_active_account_reference('user_id');
CREATE TRIGGER active_account BEFORE INSERT OR UPDATE ON notification_preferences FOR EACH ROW EXECUTE FUNCTION require_active_account_reference('user_id');
CREATE TRIGGER active_account BEFORE INSERT ON groups FOR EACH ROW EXECUTE FUNCTION require_active_account_reference('created_by');
CREATE TRIGGER active_account BEFORE INSERT OR UPDATE ON group_members FOR EACH ROW EXECUTE FUNCTION require_active_account_reference('user_id');
CREATE TRIGGER active_account BEFORE INSERT ON expenses FOR EACH ROW EXECUTE FUNCTION require_active_account_reference('created_by');
CREATE TRIGGER active_account BEFORE INSERT ON expense_versions FOR EACH ROW EXECUTE FUNCTION require_active_account_reference('created_by');
CREATE TRIGGER active_account BEFORE INSERT ON settlements FOR EACH ROW EXECUTE FUNCTION require_active_account_reference('created_by');
CREATE TRIGGER active_account BEFORE INSERT ON savings_contributions FOR EACH ROW EXECUTE FUNCTION require_active_account_reference('user_id');
CREATE TRIGGER active_account BEFORE INSERT ON invitations FOR EACH ROW EXECUTE FUNCTION require_active_account_reference('invited_by');
CREATE TRIGGER active_account BEFORE INSERT ON group_join_links FOR EACH ROW EXECUTE FUNCTION require_active_account_reference('created_by');
CREATE TRIGGER active_account BEFORE INSERT ON assistant_action_confirmations FOR EACH ROW EXECUTE FUNCTION require_active_account_reference('user_id');
