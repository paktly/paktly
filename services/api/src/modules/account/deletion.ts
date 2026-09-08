import type { TransactionSql } from "postgres";

/** Erase personal data while preserving numerical shared financial history. */
export async function eraseAccount(tx: TransactionSql, userId: string, email: string): Promise<void> {
  // Remove outbound notifications as well: their payloads can contain the member's name.
  await tx`DELETE FROM notifications WHERE user_id=${userId}
    OR entity_id IN (SELECT id FROM invitations WHERE invited_by=${userId} OR email=${email})
    OR entity_id IN (SELECT entity_id FROM activity_events WHERE actor_user_id=${userId})`;
  await tx`DELETE FROM push_devices WHERE user_id=${userId}`;
  await tx`DELETE FROM notification_preferences WHERE user_id=${userId}`;
  await tx`DELETE FROM friends WHERE user_id=${userId}`;
  await tx`UPDATE friends SET linked_user_id=NULL WHERE linked_user_id=${userId}`;
  await tx`DELETE FROM smart_interest WHERE user_id=${userId}`;
  await tx`DELETE FROM assistant_action_confirmations WHERE user_id=${userId}`;
  await tx`DELETE FROM assistant_usage_daily WHERE user_id=${userId}`;
  await tx`DELETE FROM email_otp_challenges WHERE email=${email}`;
  await tx`DELETE FROM invitations WHERE email=${email} OR invited_by=${userId} OR accepted_by=${userId}`;
  await tx`DELETE FROM group_join_links WHERE created_by=${userId}`;
  await tx`DELETE FROM auth_sessions WHERE user_id=${userId}`;
  await tx`DELETE FROM auth_identities WHERE user_id=${userId}`;
  await tx`DELETE FROM wallet_addresses WHERE user_id=${userId}`;

  // Financial amounts, payer/split references, and journal lines are never rewritten.
  await tx`UPDATE expense_versions SET description='Shared expense', notes=NULL WHERE created_by=${userId}`;
  await tx`UPDATE journal_entries SET description='Shared financial record' WHERE created_by=${userId}`;
  await tx`UPDATE settlements SET note=NULL WHERE created_by=${userId}`;
  await tx`UPDATE savings_contributions SET note=NULL WHERE user_id=${userId}`;
  await tx`UPDATE activity_events SET actor_user_id=NULL, summary='Deleted member activity', metadata='{}'
    WHERE actor_user_id=${userId}`;
  await tx`UPDATE groups SET name='Shared plan', description=NULL WHERE created_by=${userId}`;
  // Transfer ownership so a remaining member can continue managing the plan.
  await tx`UPDATE group_members gm SET role='OWNER' WHERE (gm.group_id,gm.user_id) IN (
    SELECT DISTINCT ON (other.group_id) other.group_id,other.user_id
    FROM group_members other JOIN group_members departing ON departing.group_id=other.group_id
    JOIN users u ON u.id=other.user_id
    WHERE departing.user_id=${userId} AND departing.role='OWNER' AND departing.status='ACTIVE'
      AND other.user_id<>${userId} AND other.status='ACTIVE' AND u.status='ACTIVE'
    ORDER BY other.group_id, CASE WHEN other.role='ADMIN' THEN 0 ELSE 1 END,other.joined_at,other.user_id
  )`;
  await tx`UPDATE group_members SET status='LEFT' WHERE user_id=${userId}`;
  await tx`UPDATE user_profiles SET display_name='Deleted member',username=NULL,avatar_url=NULL,
    default_currency='USD',locale='en-US',timezone='UTC',updated_at=now() WHERE user_id=${userId}`;
  await tx`UPDATE users SET email=${`deleted-${userId}@users.paktly.invalid`},status='DELETED',updated_at=now()
    WHERE id=${userId}`;
}
