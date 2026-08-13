-- Draft employee records.
-- Supporting-evidence uploads (compliance.supporting_document) carry a
-- hard FK to employee.employee_master(id), so a record must exist in
-- the database *before* any document can be attached to it. Wizards
-- previously only created the row on final submit, meaning document
-- evidence steps had no valid id to upload against until the very
-- end. This migration lets a near-empty "Draft" row be created the
-- moment a wizard opens (id generated client-side, see
-- lib/*-store.ts createDraft()), which every step - including
-- document evidence - then just PATCHes into.
--
-- Draft rows are excluded from every normal listing/dashboard/
-- compliance query (see employee.service.ts) and are only ever
-- promoted to 'Active' by the finalize step, at which point the
-- original required-field validation is (re-)enforced.

-- 1. The 6 columns a fresh draft can't possibly have yet.
ALTER TABLE employee.employee_master ALTER COLUMN first_name DROP NOT NULL;
ALTER TABLE employee.employee_master ALTER COLUMN last_name DROP NOT NULL;
ALTER TABLE employee.employee_master ALTER COLUMN date_of_birth DROP NOT NULL;
ALTER TABLE employee.employee_master ALTER COLUMN job_title DROP NOT NULL;
ALTER TABLE employee.employee_master ALTER COLUMN department_id DROP NOT NULL;
ALTER TABLE employee.employee_master ALTER COLUMN date_of_joining DROP NOT NULL;

-- 2. New status. Drafts sit outside the Active/Inactive/Exited
-- lifecycle entirely - they aren't a "kind of" active employee, so
-- reusing the existing production statuses would be misleading and
-- would risk instantly leaking a half-filled record into UI states
-- that call updateStatus() generically.
ALTER TABLE employee.employee_master DROP CONSTRAINT ck_employee_status;
ALTER TABLE employee.employee_master ADD CONSTRAINT ck_employee_status
  CHECK (record_status IN ('Draft', 'Active', 'Inactive', 'Exited'));

-- 3. employee_reference_no is generated at draft time same as
-- before (genRef(), still unique/NOT NULL) so uq_employee_tenant_reference
-- is unaffected. ni_number_hash uniqueness only ever applies once a
-- real NI number is entered (constraint already tolerates NULLs -
-- multiple drafts with no NI number is fine, Postgres treats NULLs
-- as distinct for UNIQUE).

-- 4. Cheap filter for every "real employees only" query.
CREATE INDEX idx_employee_record_status ON employee.employee_master(tenant_id, record_status);
