-- Employee login support (Item #3/#4 of the role-aware access work).
--
-- security.credential already exists (created outside this repo's
-- migration history - see migrations/004_auth_service_role.sql's
-- comment) with at minimum: id, tenant_id, email, password_hash. This
-- migration only ADDs to it - it does not assume anything else about
-- its current shape beyond what AuthService.login() already queries
-- successfully in production.

ALTER TABLE security.credential ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'hr_admin';
ALTER TABLE security.credential DROP CONSTRAINT IF EXISTS ck_credential_role;
ALTER TABLE security.credential ADD CONSTRAINT ck_credential_role CHECK (role IN ('hr_admin', 'employee'));

-- Links an employee-role credential back to the employee it belongs
-- to - this is how AuthGuard resolves "which records can this session
-- touch" for the self-only enforcement in attendance/leave. NULL for
-- hr_admin credentials, which aren't scoped to a single employee.
ALTER TABLE security.credential ADD COLUMN IF NOT EXISTS employee_id UUID REFERENCES employee.employee_master(id);
CREATE UNIQUE INDEX IF NOT EXISTS uq_credential_employee_id ON security.credential(employee_id) WHERE employee_id IS NOT NULL;

-- Default password is the employee's id label (E000001-style) at
-- provisioning time - this flag drives the forced change-password
-- redirect on first login.
ALTER TABLE security.credential ADD COLUMN IF NOT EXISTS must_change_password BOOLEAN NOT NULL DEFAULT false;

-- AuthService previously only ever SELECTed from security.credential
-- (004_auth_service_role.sql). Provisioning an employee credential at
-- onboarding time, and letting a user change their own password, both
-- need to write - widening the grant here rather than introducing a
-- second role keeps the "only AuthService's own connection ever
-- touches security.credential" boundary intact (Database Design -
-- Common Platform Standards, Section 4.6) while still letting exactly
-- one, already-locked-down role do the writing.
GRANT INSERT, UPDATE ON security.credential TO auth_service;

-- The domain half of an employee's login email (E000001@<this>) - set
-- once by HR in Employer Settings. Deliberately NOT auto-derived from
-- company_name (e.g. "ABC Solutions Ltd." has no unambiguous slug) -
-- HR sets it explicitly so login emails are predictable.
ALTER TABLE reference.employer_profile ADD COLUMN IF NOT EXISTS email_domain TEXT;
