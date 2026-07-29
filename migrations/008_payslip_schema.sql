-- Payslip module schema.
--
-- 1. employee.employee_master gains hourly_rate - this never existed
--    anywhere before (the Employee wizard's Work step never captured
--    a pay rate), and Payslip cannot honestly compute anything without
--    it. Nullable, since existing employees have no rate yet.
--
-- 2. reference.payslip_component replaces the in-memory-only
--    PayslipComponentSettingsProvider (components/providers/
--    PayslipComponentSettingsProvider.tsx) with a real, tenant-shared
--    table - Settings > Payslip Components edits should be persisted
--    here going forward, not lost every time the browser tab closes.
--    Seeded from the exact same PAYSLIP_EARNINGS/PAYSLIP_DEDUCTIONS
--    lists in lib/settings-data.ts (same ids-as-slugs, same default
--    enabled/disabled state), the same seed-on-first-read pattern as
--    reference.leave_type.

ALTER TABLE employee.employee_master ADD COLUMN IF NOT EXISTS hourly_rate NUMERIC(10, 2);

CREATE TABLE reference.payslip_component (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  slug TEXT NOT NULL, -- matches lib/settings-data.ts's existing `id` values (e.g. "earn-basic", "ded-paye")
  name TEXT NOT NULL,
  description TEXT,
  component_type TEXT NOT NULL,
  is_selected BOOLEAN NOT NULL DEFAULT true,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_payslip_component_tenant_slug UNIQUE (tenant_id, slug),
  CONSTRAINT ck_payslip_component_type CHECK (component_type IN ('earning', 'deduction'))
);
CREATE INDEX idx_payslip_component_tenant ON reference.payslip_component(tenant_id);

ALTER TABLE reference.payslip_component ENABLE ROW LEVEL SECURITY;
CREATE POLICY payslip_component_tenant_isolation ON reference.payslip_component
  USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);

-- reference.payslip_component specifically - same rationale as
-- reference.leave_type in migration 007: Settings actions on this
-- table need DELETE, which the schema-wide grant in migration 002
-- doesn't include.
GRANT SELECT, INSERT, UPDATE, DELETE ON reference.payslip_component TO app_service;
