ALTER TABLE groups ADD COLUMN client_operation_id uuid;
CREATE UNIQUE INDEX groups_creator_operation_unique ON groups(created_by, client_operation_id) WHERE client_operation_id IS NOT NULL;
