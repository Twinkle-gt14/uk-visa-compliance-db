-- Compliance module: Home Office Skilled Worker rules, kept
-- deliberately separate from reference.soc_occupation_master (the ONS
-- classification). SOC answers "what occupation is this?"; this
-- schema answers "what Skilled Worker sponsorship rules apply to it?".
-- The two are linked only by soc_code - never merged into one table.
CREATE SCHEMA IF NOT EXISTS compliance;

-- ---------------------------------------------------------------------
-- compliance.skilled_worker_occupation_master
-- One row per (tenant, soc_code, source_table) version. Historical
-- versions are never overwritten: closing a version sets effective_to,
-- and a new Home Office update inserts a new row with effective_from
-- set and effective_to left NULL. The partial unique index below is
-- what actually enforces "only one active version at a time" rather
-- than leaving it as a convention the application has to remember.
-- ---------------------------------------------------------------------
CREATE TABLE compliance.skilled_worker_occupation_master (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  soc_code TEXT NOT NULL,
  source_table TEXT NOT NULL, -- 'Table 1', 'Table 1a', 'Table 2', 'Table 2aa', 'Table 2a', 'Table 2b', 'Table 3', 'Table 3a', 'Table 6'
  status TEXT NOT NULL DEFAULT 'Not Mapped', -- Eligible | Not Eligible | Conditional | Transitional | Not Mapped
  home_office_related_job_titles TEXT,
  going_rate NUMERIC,
  going_rate_90 NUMERIC,
  going_rate_80 NUMERIC,
  going_rate_70 NUMERIC,
  phd_points_eligible BOOLEAN, -- NULL = Not applicable/unknown, never inferred
  special_conditions TEXT,
  effective_from DATE NOT NULL DEFAULT CURRENT_DATE,
  effective_to DATE, -- NULL = currently active
  source_version TEXT,
  source_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT fk_skilled_worker_soc_code FOREIGN KEY (tenant_id, soc_code)
    REFERENCES reference.soc_occupation_master (tenant_id, soc_code)
);

-- Only one ACTIVE (effective_to IS NULL) row per soc_code/source_table
-- per tenant - this is the actual enforcement of the versioning rule.
CREATE UNIQUE INDEX uq_skilled_worker_active_version
  ON compliance.skilled_worker_occupation_master (tenant_id, soc_code, source_table)
  WHERE effective_to IS NULL;

CREATE INDEX idx_skilled_worker_tenant ON compliance.skilled_worker_occupation_master(tenant_id);
CREATE INDEX idx_skilled_worker_soc_code ON compliance.skilled_worker_occupation_master(soc_code);
CREATE INDEX idx_skilled_worker_status ON compliance.skilled_worker_occupation_master(status);
CREATE INDEX idx_skilled_worker_source_table ON compliance.skilled_worker_occupation_master(source_table);
CREATE INDEX idx_skilled_worker_effective_from ON compliance.skilled_worker_occupation_master(effective_from);
CREATE INDEX idx_skilled_worker_effective_to ON compliance.skilled_worker_occupation_master(effective_to);

-- ---------------------------------------------------------------------
-- compliance.import_batch / import_batch_record - audit trail for
-- every Appendix import. Nothing is written to
-- skilled_worker_occupation_master until an admin reviews the preview
-- (matched/unmatched/duplicate/invalid) and explicitly approves it.
-- ---------------------------------------------------------------------
CREATE TABLE compliance.import_batch (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  source_filename TEXT,
  status TEXT NOT NULL DEFAULT 'Pending Review', -- Pending Review | Approved | Cancelled
  matched_count INT NOT NULL DEFAULT 0,
  unmatched_count INT NOT NULL DEFAULT 0,
  duplicate_count INT NOT NULL DEFAULT 0,
  invalid_count INT NOT NULL DEFAULT 0,
  uploaded_by TEXT,
  uploaded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  reviewed_at TIMESTAMPTZ
);
CREATE INDEX idx_import_batch_tenant ON compliance.import_batch(tenant_id);

CREATE TABLE compliance.import_batch_record (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id UUID NOT NULL REFERENCES compliance.import_batch(id) ON DELETE CASCADE,
  tenant_id UUID NOT NULL,
  soc_code TEXT, -- raw extracted code; NULL when extraction itself failed
  source_table TEXT NOT NULL,
  outcome TEXT NOT NULL, -- Matched | Not Matched | Duplicate | Invalid
  raw_row_json JSONB NOT NULL,
  resolved_skilled_worker_id UUID REFERENCES compliance.skilled_worker_occupation_master(id)
);
CREATE INDEX idx_import_batch_record_batch ON compliance.import_batch_record(batch_id);
CREATE INDEX idx_import_batch_record_tenant ON compliance.import_batch_record(tenant_id);

-- ---------------------------------------------------------------------
-- Table 4 & 5 supporting salary data - pay-band-by-nation and
-- role-by-region matrices with no soc_code column in the source, so
-- they cannot be joined into skilled_worker_occupation_master. Kept as
-- their own standalone browsable reference tables instead.
-- ---------------------------------------------------------------------
CREATE TABLE reference.healthcare_pay_band (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  band_label TEXT NOT NULL, -- e.g. "Band 3"
  england NUMERIC,
  scotland NUMERIC,
  wales NUMERIC,
  northern_ireland NUMERIC,
  uploaded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_healthcare_pay_band_tenant_label UNIQUE (tenant_id, band_label)
);
CREATE INDEX idx_healthcare_pay_band_tenant ON reference.healthcare_pay_band(tenant_id);

CREATE TABLE reference.education_pay_scale (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  role_label TEXT NOT NULL, -- e.g. "Qualified teachers"
  england NUMERIC,
  london_fringe NUMERIC,
  outer_london NUMERIC,
  inner_london NUMERIC,
  scotland NUMERIC,
  wales NUMERIC,
  northern_ireland NUMERIC,
  uploaded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_education_pay_scale_tenant_role UNIQUE (tenant_id, role_label)
);
CREATE INDEX idx_education_pay_scale_tenant ON reference.education_pay_scale(tenant_id);

-- ---------------------------------------------------------------------
-- RLS - same tenant-isolation pattern as every other table in this app.
-- ---------------------------------------------------------------------
ALTER TABLE compliance.skilled_worker_occupation_master ENABLE ROW LEVEL SECURITY;
CREATE POLICY skilled_worker_occupation_master_tenant_isolation ON compliance.skilled_worker_occupation_master
  USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);

ALTER TABLE compliance.import_batch ENABLE ROW LEVEL SECURITY;
CREATE POLICY import_batch_tenant_isolation ON compliance.import_batch
  USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);

ALTER TABLE compliance.import_batch_record ENABLE ROW LEVEL SECURITY;
CREATE POLICY import_batch_record_tenant_isolation ON compliance.import_batch_record
  USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);

ALTER TABLE reference.healthcare_pay_band ENABLE ROW LEVEL SECURITY;
CREATE POLICY healthcare_pay_band_tenant_isolation ON reference.healthcare_pay_band
  USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);

ALTER TABLE reference.education_pay_scale ENABLE ROW LEVEL SECURITY;
CREATE POLICY education_pay_scale_tenant_isolation ON reference.education_pay_scale
  USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);

GRANT USAGE ON SCHEMA compliance TO app_service;
GRANT SELECT, INSERT, UPDATE, DELETE ON compliance.skilled_worker_occupation_master TO app_service;
GRANT SELECT, INSERT, UPDATE, DELETE ON compliance.import_batch TO app_service;
GRANT SELECT, INSERT, UPDATE, DELETE ON compliance.import_batch_record TO app_service;
GRANT SELECT, INSERT, UPDATE, DELETE ON reference.healthcare_pay_band TO app_service;
GRANT SELECT, INSERT, UPDATE, DELETE ON reference.education_pay_scale TO app_service;
