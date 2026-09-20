-- The HR dashboard's widget layout (which widgets show, their order and
-- width). One company-wide layout per tenant for now; a per-user layout
-- can be added later by adding a user_id column to the key.
CREATE TABLE reference.dashboard_layout (
  tenant_id UUID PRIMARY KEY,
  layout JSONB NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_by TEXT
);

ALTER TABLE reference.dashboard_layout ENABLE ROW LEVEL SECURITY;
CREATE POLICY dashboard_layout_tenant_isolation ON reference.dashboard_layout
  USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);

GRANT SELECT, INSERT, UPDATE, DELETE ON reference.dashboard_layout TO app_service;
