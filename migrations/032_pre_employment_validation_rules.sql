-- reference.pre_employment_validation_rule - the master validation
-- rules table (R1-R7 Role & Recruitment, S1-S16 Salary & Pay, R1-R16
-- Right to Work, C1-C16 CoS & Fees), uploaded from Settings >
-- Compliance > Pre-Employment Validation as a master-data Excel file,
-- same pattern as reference.soc_occupation_master (migration 012).
-- Rule IDs repeat across categories (e.g. "R1" exists under both
-- Role & Recruitment and Right to Work), so the natural key is
-- (tenant_id, category, rule_id), not rule_id alone. Tenant-scoped
-- and re-uploadable: uploading again upserts on that key rather than
-- duplicating, so a corrected file can be re-uploaded safely.
CREATE TABLE reference.pre_employment_validation_rule (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  category TEXT NOT NULL,
  rule_id TEXT NOT NULL,
  checkpoint TEXT,
  consequence TEXT,
  source TEXT,
  uploaded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_pre_employment_validation_rule_tenant_category_rule UNIQUE (tenant_id, category, rule_id)
);
CREATE INDEX idx_pre_employment_validation_rule_tenant ON reference.pre_employment_validation_rule(tenant_id);

ALTER TABLE reference.pre_employment_validation_rule ENABLE ROW LEVEL SECURITY;
CREATE POLICY pre_employment_validation_rule_tenant_isolation ON reference.pre_employment_validation_rule
  USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);

GRANT SELECT, INSERT, UPDATE, DELETE ON reference.pre_employment_validation_rule TO app_service;
