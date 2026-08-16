-- Settings > Position is being renamed to Settings > Role throughout
-- the app (UI, backend, DB) - this migration catches the DB up:
-- reference.position becomes reference.role, along with its
-- dependent constraint, index, and RLS policy names, so nothing is
-- left pointing at the old "position" name. Column shape is
-- untouched (see migration 026); table privileges (migration 009's
-- GRANT ... ON reference.position TO app_service) follow the rename
-- automatically in Postgres, so no re-grant is needed.

ALTER TABLE reference.position RENAME TO role;

ALTER TABLE reference.role RENAME CONSTRAINT uq_position_tenant_name TO uq_role_tenant_name;

ALTER INDEX reference.idx_position_tenant RENAME TO idx_role_tenant;

ALTER POLICY position_tenant_isolation ON reference.role RENAME TO role_tenant_isolation;
