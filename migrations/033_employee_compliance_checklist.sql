-- reference.employee_compliance_checklist - the post-joining UK
-- employer/sponsor duties checklist, uploaded from Settings >
-- Compliance > Employee Compliance as a master-data Excel file, same
-- pattern as reference.pre_employment_validation_rule (migration
-- 032), but a genuinely different shape: two categories (Sponsored
-- Workers / Non-Sponsored Employees, one per source workbook sheet),
-- each with its own section groupings and column set (Trigger Event,
-- Deadline, Action/Where to Report are specific to this checklist,
-- not shared with the pre-employment rules table).
CREATE TABLE reference.employee_compliance_checklist (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  category TEXT NOT NULL,
  section TEXT,
  compliance_area TEXT NOT NULL,
  check_requirement TEXT,
  trigger_event TEXT,
  deadline TEXT,
  action_where_to_report TEXT,
  consequence TEXT,
  source TEXT,
  uploaded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_employee_compliance_checklist_tenant_category_area UNIQUE (tenant_id, category, compliance_area)
);
CREATE INDEX idx_employee_compliance_checklist_tenant ON reference.employee_compliance_checklist(tenant_id);

ALTER TABLE reference.employee_compliance_checklist ENABLE ROW LEVEL SECURITY;
CREATE POLICY employee_compliance_checklist_tenant_isolation ON reference.employee_compliance_checklist
  USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);

GRANT SELECT, INSERT, UPDATE, DELETE ON reference.employee_compliance_checklist TO app_service;
