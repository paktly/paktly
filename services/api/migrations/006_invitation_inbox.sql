ALTER TABLE invitations DROP CONSTRAINT invitations_status_check;
ALTER TABLE invitations ADD CONSTRAINT invitations_status_check
  CHECK (status IN ('PENDING','ACCEPTED','DECLINED','REVOKED','EXPIRED'));

CREATE INDEX invitations_recipient_pending
  ON invitations(email, expires_at DESC)
  WHERE status='PENDING';
