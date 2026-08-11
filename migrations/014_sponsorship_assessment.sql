-- compliance.sponsorship_assessment - a point-in-time record of what
-- Skilled Worker eligibility/rate an admin saw for a candidate's SOC
-- code at the moment they recorded an assessment (Pre-Employment
-- Compliance Check > Immigration / Sponsorship Assessment). This is a
-- snapshot, not a live join - skilled_worker_occupation_master's rules
-- can change over time (see its own versioning model), so a past
-- assessment must keep showing what was actually true when it was
-- made, not silently update if the underlying rule changes later.
CREATE TABLE compliance.sponsorship_assessment (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  employee_id UUID NOT NULL REFERENCES employee.employee_master(id),
  soc_code TEXT,
  soc_title TEXT,
  status TEXT, -- snapshot of the Skilled Worker status seen at assessment time
  source_table TEXT,
  going_rate NUMERIC,
  notes TEXT,
  assessed_by TEXT,
  assessed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_sponsorship_assessment_tenant ON compliance.sponsorship_assessment(tenant_id);
CREATE INDEX idx_sponsorship_assessment_employee ON compliance.sponsorship_assessment(employee_id);

ALTER TABLE compliance.sponsorship_assessment ENABLE ROW LEVEL SECURITY;
CREATE POLICY sponsorship_assessment_tenant_isolation ON compliance.sponsorship_assessment
  USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);

GRANT SELECT, INSERT ON compliance.sponsorship_assessment TO app_service;
