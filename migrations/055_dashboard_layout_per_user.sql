-- Dashboard layouts become per user (were one shared layout per tenant).
-- The existing shared layout is copied onto every HR admin of that tenant
-- so nobody loses the dashboard they had, then the shared row is removed.
ALTER TABLE reference.dashboard_layout DROP CONSTRAINT dashboard_layout_pkey;
ALTER TABLE reference.dashboard_layout ADD COLUMN user_id UUID;

INSERT INTO reference.dashboard_layout (tenant_id, user_id, layout, updated_by)
SELECT l.tenant_id, c.id, l.layout, l.updated_by
FROM reference.dashboard_layout l
JOIN security.credential c ON c.tenant_id = l.tenant_id AND c.role = 'hr_admin'
WHERE l.user_id IS NULL;

DELETE FROM reference.dashboard_layout WHERE user_id IS NULL;

ALTER TABLE reference.dashboard_layout ALTER COLUMN user_id SET NOT NULL;
ALTER TABLE reference.dashboard_layout ADD PRIMARY KEY (tenant_id, user_id);
