-- Users & Roles: roles become data, with menu-level permissions, so an Admin can create custom roles
-- (e.g. "HR", "Recruiter") and assign them to users.
--
-- access_level keeps deciding what the API allows, exactly as before:
--   admin    -> everything HR can do, plus managing users and roles
--   hr       -> the HR/admin API surface (the old 'hr_admin')
--   employee -> own records only
-- permissions (text[]) decide which menus and pages a user of that role sees.

CREATE TABLE security.role (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  access_level TEXT NOT NULL,
  permissions TEXT[] NOT NULL DEFAULT '{}',
  is_system BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ck_role_access_level CHECK (access_level IN ('admin', 'hr', 'employee'))
);
CREATE UNIQUE INDEX uq_role_tenant_name ON security.role (tenant_id, lower(name));

ALTER TABLE security.credential
  ADD COLUMN role_id UUID REFERENCES security.role(id),
  ADD COLUMN is_active BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN display_name TEXT;

-- credential.role is deliberately left as it is ('hr_admin' | 'employee'): the deployed API reads this same
-- table and only understands those two values. An Admin is simply an 'hr_admin' credential whose role_id
-- points at an access_level = 'admin' role; the current API derives the 'admin' level from that.

-- Built-in roles for every tenant that already has a login.
INSERT INTO security.role (tenant_id, name, description, access_level, permissions, is_system)
SELECT t.tenant_id, r.name, r.description, r.access_level, r.permissions, true
FROM (SELECT DISTINCT tenant_id FROM security.credential) t
CROSS JOIN (VALUES
  ('Admin', 'Full access, including managing users and roles.', 'admin',
    ARRAY['dashboard.view','candidates.view','employees.view','compliance.view','workflow.view','attendance.calendar.view','leave.summary.view','payslip.view','settings.view','subscription.view','help.view','users.view']),
  ('HR', 'Manages candidates, employees, compliance and approvals.', 'hr',
    ARRAY['dashboard.view','candidates.view','employees.view','compliance.view','workflow.view','attendance.calendar.view','leave.summary.view','payslip.view','settings.view','subscription.view','help.view']),
  ('Employee', 'Self-service access to their own records.', 'employee',
    ARRAY['dashboard.view','employees.view','attendance.calendar.view','leave.summary.view','leave.view','leave.apply','resignation.view','help.view'])
) AS r(name, description, access_level, permissions);

-- Existing logins: employees get the Employee role; the existing HR login gets the Admin role so someone
-- can manage users and roles from day one.
UPDATE security.credential c
SET role_id = r.id
FROM security.role r
WHERE r.tenant_id = c.tenant_id AND r.name = 'Employee' AND c.role = 'employee';

UPDATE security.credential c
SET role_id = r.id
FROM security.role r
WHERE r.tenant_id = c.tenant_id AND r.name = 'Admin' AND c.role = 'hr_admin';

-- The auth connection reads and writes roles and users (same boundary as security.credential).
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'auth_service') THEN
    GRANT SELECT, INSERT, UPDATE, DELETE ON security.role TO auth_service;
  END IF;
END $$;
