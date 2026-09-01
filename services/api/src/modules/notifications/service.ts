import type { Sql, TransactionSql } from "postgres";

export async function reconcileInvitationNotifications(database: Sql | TransactionSql, userId: string, email: string): Promise<void> {
  await database`
    INSERT INTO notifications(id,user_id,group_id,type,title,body,entity_type,entity_id,category,data,deep_link,deduplication_key,priority,expires_at)
    SELECT gen_random_uuid(),${userId},i.group_id,'INVITATION_RECEIVED','You were invited',
      p.display_name||' invited you to '||g.name,'INVITATION',i.id,'INVITATION',
      jsonb_build_object('invitationId',i.id,'groupId',i.group_id),
      'paktly://invitation/'||i.id,'invitation:'||i.id,'HIGH',i.expires_at
    FROM invitations i JOIN groups g ON g.id=i.group_id JOIN user_profiles p ON p.user_id=i.invited_by
    WHERE i.email=${email} AND i.status='PENDING' AND i.expires_at>now() AND g.status='ACTIVE'
    ON CONFLICT(user_id,deduplication_key) WHERE deduplication_key IS NOT NULL DO NOTHING
  `;
}
