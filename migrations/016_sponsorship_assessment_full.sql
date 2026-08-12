-- compliance.sponsorship_assessment was created in migration 014 as a
-- lightweight SOC-eligibility snapshot. The Immigration / Sponsorship
-- Assessment screen now captures a full assessment (route, computed
-- Pass/Fail checks with override, ISL snapshot, and the reviewer's
-- decision), so this extends it rather than replacing it - the table
-- stays append-only (INSERT only, no UPDATE/DELETE granted), so every
-- extension here is additive and safe for rows already written.
ALTER TABLE compliance.sponsorship_assessment
  ADD COLUMN proposed_route TEXT DEFAULT 'Skilled Worker',
  ADD COLUMN checks_json JSONB, -- the full Section 3 A/B/C check grid: {checkId: {computed, override, result}}
  ADD COLUMN overall_result TEXT, -- Eligible | Not Eligible | Further Review - derived from checks_json at save time
  ADD COLUMN decision TEXT, -- Eligible for Sponsorship | Further Review Required | Not Eligible for Sponsorship
  ADD COLUMN reviewer TEXT,
  ADD COLUMN assessment_date DATE,
  ADD COLUMN remarks TEXT,
  ADD COLUMN isl_listed BOOLEAN,
  ADD COLUMN isl_jurisdiction TEXT,
  ADD COLUMN isl_criteria TEXT,
  ADD COLUMN isl_removal_date DATE,
  ADD COLUMN isl_source_version TEXT;
