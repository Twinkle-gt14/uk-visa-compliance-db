-- "Salary offered" - new field on the Role/Work Details step, shared
-- by both Candidate Onboarding and Employee Register (same underlying
-- employee_master row, same as every other cross-module field).
ALTER TABLE employee.employee_master
  ADD COLUMN salary_offered TEXT;

-- Field-level change audit trail. One row per changed field per save -
-- a single edit that changes 3 fields produces 3 rows sharing the same
-- changed_at/changed_by, so the History tab can show them individually
-- while still being able to group by "what happened in one save" via
-- changed_at if ever needed. Deliberately generic (category + field
-- label as free text, not a fixed enum) so it can cover every step in
-- both wizards without a schema change every time a new field is added.
CREATE TABLE employee.employee_change_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  employee_id UUID NOT NULL REFERENCES employee.employee_master(id),
  category TEXT NOT NULL, -- the tab/step this field belongs to, e.g. "Work Details", "Passport"
  field_label TEXT NOT NULL, -- e.g. "Job Title"
  old_value TEXT,
  new_value TEXT,
  changed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  changed_by TEXT, -- the acting user's email/name at the time of change
  evidence_file_reference TEXT -- populated when a change required supporting evidence (passport/visa/CoS)
);
CREATE INDEX idx_employee_change_history_employee ON employee.employee_change_history(employee_id, changed_at DESC);

-- employee_document had no timestamp at all, so there was no way to
-- tell "a document already on file from before" apart from "evidence
-- just uploaded as part of this change" - needed to enforce the new
-- mandatory-evidence-on-passport/visa/CoS-change rule. Backfilled to
-- now() for existing rows (better than NULL; the exact original
-- upload time for pre-existing documents isn't recoverable).
ALTER TABLE employee.employee_document
  ADD COLUMN created_at TIMESTAMPTZ NOT NULL DEFAULT now();
