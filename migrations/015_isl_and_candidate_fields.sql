-- ---------------------------------------------------------------------
-- 1. New candidate fields for the Immigration / Sponsorship Assessment
--    screen's Proposed Employment section.
-- ---------------------------------------------------------------------
ALTER TABLE employee.employee_master
  ADD COLUMN job_description TEXT,
  ADD COLUMN contract_duration TEXT,
  ADD COLUMN current_location TEXT,
  ADD COLUMN current_immigration_status TEXT,
  ADD COLUMN proposed_annual_salary NUMERIC;

-- ---------------------------------------------------------------------
-- 2. UK Jurisdiction Master (FSD section 3.2) - seed values only, per
--    the FSD's own instruction that these are data values, not
--    hardcoded columns. Seeding the four current UK nations here is
--    the FSD's explicit design, not invented data.
-- ---------------------------------------------------------------------
CREATE TABLE reference.uk_jurisdiction (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  code TEXT NOT NULL,
  name TEXT NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  CONSTRAINT uq_uk_jurisdiction_tenant_code UNIQUE (tenant_id, code)
);
CREATE INDEX idx_uk_jurisdiction_tenant ON reference.uk_jurisdiction(tenant_id);
ALTER TABLE reference.uk_jurisdiction ENABLE ROW LEVEL SECURITY;
CREATE POLICY uk_jurisdiction_tenant_isolation ON reference.uk_jurisdiction
  USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);
GRANT SELECT, INSERT, UPDATE, DELETE ON reference.uk_jurisdiction TO app_service;

-- Seeded per tenant by the application on first use rather than here,
-- since this migration has no tenant_id to seed against (tenants are
-- created after migrations run). See SettingsService.ensureJurisdictionsSeeded.

-- ---------------------------------------------------------------------
-- 3. Work Location now resolves to a jurisdiction, for the ISL lookup
--    (FSD section 5: "resolve the location to the applicable UK
--    jurisdiction"). Nullable - existing work locations aren't
--    retroactively assigned one; the admin sets it via Settings.
-- ---------------------------------------------------------------------
ALTER TABLE reference.work_location
  ADD COLUMN jurisdiction_id UUID REFERENCES reference.uk_jurisdiction(id);

-- ---------------------------------------------------------------------
-- 4. Immigration Salary List (ISL) schema, per the FSD.
--
-- isl_version is the import/publish batch entity (FSD section 10.5's
-- Draft -> Validation -> Review -> Approved -> Published lifecycle,
-- simplified in this implementation to Draft -> Published -> Superseded:
-- Draft covers the "uploaded, being previewed/validated" state, and
-- Published/Superseded gives the "only one version applicable to a
-- given date, never edited in place" behaviour the FSD requires,
-- without a separate multi-person Validation/Review approval workflow
-- that the FSD doesn't otherwise describe (no separate reviewer role
-- is defined for ISL, unlike the Sponsorship Assessment's own
-- Reviewer field). Each occupation row belongs to exactly one version.
-- ---------------------------------------------------------------------
CREATE TABLE compliance.isl_version (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  status TEXT NOT NULL DEFAULT 'Draft', -- Draft | Published | Superseded | Rejected
  source_filename TEXT,
  source_version TEXT,
  source_url TEXT,
  effective_from DATE,
  effective_to DATE,
  uploaded_by TEXT,
  uploaded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  published_by TEXT,
  published_at TIMESTAMPTZ,
  matched_count INT NOT NULL DEFAULT 0,
  not_matched_count INT NOT NULL DEFAULT 0,
  duplicate_count INT NOT NULL DEFAULT 0,
  invalid_count INT NOT NULL DEFAULT 0
);
CREATE INDEX idx_isl_version_tenant ON compliance.isl_version(tenant_id);
CREATE INDEX idx_isl_version_status ON compliance.isl_version(status);

CREATE TABLE compliance.isl_occupation (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  isl_version_id UUID NOT NULL REFERENCES compliance.isl_version(id),
  soc_2020_code TEXT NOT NULL,
  occupation_criteria TEXT,
  removal_date DATE,
  effective_from DATE NOT NULL,
  effective_to DATE,
  is_active BOOLEAN NOT NULL DEFAULT true
);
CREATE INDEX idx_isl_occupation_tenant ON compliance.isl_occupation(tenant_id);
CREATE INDEX idx_isl_occupation_version ON compliance.isl_occupation(isl_version_id);
CREATE INDEX idx_isl_occupation_soc_code ON compliance.isl_occupation(soc_2020_code);

CREATE TABLE compliance.isl_jurisdiction_applicability (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  isl_occupation_id UUID NOT NULL REFERENCES compliance.isl_occupation(id) ON DELETE CASCADE,
  jurisdiction_id UUID NOT NULL REFERENCES reference.uk_jurisdiction(id),
  is_listed BOOLEAN NOT NULL,
  jurisdiction_criteria TEXT,
  CONSTRAINT uq_isl_applicability_occupation_jurisdiction UNIQUE (isl_occupation_id, jurisdiction_id)
);
CREATE INDEX idx_isl_applicability_tenant ON compliance.isl_jurisdiction_applicability(tenant_id);
CREATE INDEX idx_isl_applicability_occupation ON compliance.isl_jurisdiction_applicability(isl_occupation_id);
CREATE INDEX idx_isl_applicability_jurisdiction ON compliance.isl_jurisdiction_applicability(jurisdiction_id);

-- Staging table for the import preview (FSD 10.3: "preview additions,
-- changes, removals... before publication") - mirrors
-- compliance.import_batch_record's shape but scoped to an isl_version
-- instead, since isl_version is its own dedicated entity with fields
-- (source_version, source_url, effective dates, published_by/at) the
-- generic import_batch doesn't carry. Nothing here becomes a real
-- isl_occupation/isl_jurisdiction_applicability row until publish.
CREATE TABLE compliance.isl_version_record (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  isl_version_id UUID NOT NULL REFERENCES compliance.isl_version(id) ON DELETE CASCADE,
  tenant_id UUID NOT NULL,
  soc_2020_code TEXT,
  outcome TEXT NOT NULL, -- Matched | Not Matched | Duplicate | Invalid
  raw_row_json JSONB NOT NULL
);
CREATE INDEX idx_isl_version_record_version ON compliance.isl_version_record(isl_version_id);
CREATE INDEX idx_isl_version_record_tenant ON compliance.isl_version_record(tenant_id);

ALTER TABLE compliance.isl_version ENABLE ROW LEVEL SECURITY;
CREATE POLICY isl_version_tenant_isolation ON compliance.isl_version
  USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);

ALTER TABLE compliance.isl_occupation ENABLE ROW LEVEL SECURITY;
CREATE POLICY isl_occupation_tenant_isolation ON compliance.isl_occupation
  USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);

ALTER TABLE compliance.isl_jurisdiction_applicability ENABLE ROW LEVEL SECURITY;
CREATE POLICY isl_jurisdiction_applicability_tenant_isolation ON compliance.isl_jurisdiction_applicability
  USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);

ALTER TABLE compliance.isl_version_record ENABLE ROW LEVEL SECURITY;
CREATE POLICY isl_version_record_tenant_isolation ON compliance.isl_version_record
  USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);

GRANT SELECT, INSERT, UPDATE, DELETE ON compliance.isl_version TO app_service;
GRANT SELECT, INSERT, UPDATE, DELETE ON compliance.isl_occupation TO app_service;
GRANT SELECT, INSERT, UPDATE, DELETE ON compliance.isl_jurisdiction_applicability TO app_service;
GRANT SELECT, INSERT, UPDATE, DELETE ON compliance.isl_version_record TO app_service;
