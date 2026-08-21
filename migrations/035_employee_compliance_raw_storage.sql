-- Replacing the structured employee_compliance_checklist table (and
-- all its column-detection/Type-column/section-tracking parsing
-- logic) with a much simpler, more robust model: every uploaded
-- sheet's rows are stored exactly as they appear in the file - each
-- row as a raw ordered array of cell values, tagged with its sheet
-- name and original row position. No attempt to interpret which
-- column means what; the UI just reproduces the sheet faithfully.
-- This trades away the auto-derived compliance-status feature (which
-- depended on typed columns like compliance_area) for something that
-- can never silently corrupt or misparse the uploaded file's content.
DROP TABLE IF EXISTS reference.employee_compliance_checklist;

CREATE TABLE reference.employee_compliance_upload_row (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  sheet_name TEXT NOT NULL,
  row_index INTEGER NOT NULL,
  cells JSONB NOT NULL,
  uploaded_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_employee_compliance_upload_row_tenant ON reference.employee_compliance_upload_row(tenant_id);

ALTER TABLE reference.employee_compliance_upload_row ENABLE ROW LEVEL SECURITY;
CREATE POLICY employee_compliance_upload_row_tenant_isolation ON reference.employee_compliance_upload_row
  USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);

GRANT SELECT, INSERT, DELETE ON reference.employee_compliance_upload_row TO app_service;
