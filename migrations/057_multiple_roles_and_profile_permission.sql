-- A user can hold more than one role (e.g. HR + Employee); their permissions are the combination.
-- credential.role_id stays as the user's first ("primary") role; any further roles live here.
CREATE TABLE security.credential_role (
  credential_id UUID NOT NULL REFERENCES security.credential(id) ON DELETE CASCADE,
  role_id UUID NOT NULL REFERENCES security.role(id) ON DELETE RESTRICT,
  PRIMARY KEY (credential_id, role_id)
);
CREATE INDEX idx_credential_role_role ON security.credential_role(role_id);

-- New self-service permission: opening one's own employee profile from the menu.
UPDATE security.role
SET permissions = array_append(permissions, 'profile.self')
WHERE access_level = 'employee' AND NOT ('profile.self' = ANY(permissions));

-- Staff-level roles were seeded without the self-service permissions, and stay that way - a person who is both
-- staff and an employee is given both roles instead.

DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'auth_service') THEN
    GRANT SELECT, INSERT, UPDATE, DELETE ON security.credential_role TO auth_service;
  END IF;
END $$;
