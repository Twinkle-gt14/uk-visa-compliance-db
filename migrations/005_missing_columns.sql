-- Adds two columns discovered missing during end-to-end testing:
-- neither reportingManager nor photoFileName (both captured by the
-- frontend wizard) had anywhere to be written to at all.
--
-- reporting_manager_name is TEXT, not a UUID FK to another employee
-- record - the delivered frontend captures a free-text name in this
-- field, not a selected employee reference, so a self-referencing FK
-- (as a stricter design might use) would not match what's actually
-- submitted. The existing reporting_manager_id column is left in
-- place, unused, rather than removed, in case a real employee-lookup
-- version of this field is built later.

ALTER TABLE employee.employee_master ADD COLUMN IF NOT EXISTS reporting_manager_name TEXT;
ALTER TABLE employee.employee_master ADD COLUMN IF NOT EXISTS photo_file_reference TEXT;
