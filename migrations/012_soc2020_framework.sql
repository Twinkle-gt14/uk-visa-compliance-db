-- reference.soc_occupation_master - the ONS SOC 2020 occupation
-- hierarchy, uploaded from Settings > SOC2020 Framework as a
-- master-data Excel file (major group down to the 4-digit SOC Unit
-- Group, the selectable level). This is the authoritative occupation
-- classification, kept deliberately separate from Home Office Skilled
-- Worker eligibility rules (see compliance.skilled_worker_occupation_master,
-- migration 013) - SOC answers "what occupation is this?", Skilled
-- Worker rules answer "what sponsorship rules apply to it?". Tenant-
-- scoped and re-uploadable: uploading again upserts by (tenant_id,
-- soc_code) rather than duplicating, so a corrected file can be
-- re-uploaded safely.
CREATE TABLE reference.soc_occupation_master (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  soc_code TEXT NOT NULL,
  soc_title TEXT,
  major_group TEXT,
  major_group_title TEXT,
  sub_major_group TEXT,
  sub_major_group_title TEXT,
  minor_group TEXT,
  minor_group_title TEXT,
  change_note TEXT,
  verno TEXT,
  uploaded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_soc_occupation_tenant_code UNIQUE (tenant_id, soc_code)
);
CREATE INDEX idx_soc_occupation_master_tenant ON reference.soc_occupation_master(tenant_id);

ALTER TABLE reference.soc_occupation_master ENABLE ROW LEVEL SECURITY;
CREATE POLICY soc_occupation_master_tenant_isolation ON reference.soc_occupation_master
  USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);

GRANT SELECT, INSERT, UPDATE, DELETE ON reference.soc_occupation_master TO app_service;
