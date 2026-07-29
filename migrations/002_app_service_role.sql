-- Creates app_service: the role the API connects as in production.
-- Run via the migration runner (scripts/migrate.js), which reads
-- APP_SERVICE_PASSWORD from the environment and passes it in with
-- set_config() - do not commit a real password into this file.
--
-- WHY THIS MATTERS: every ENABLE ROW LEVEL SECURITY / CREATE POLICY
-- statement in 001_employee_schema.sql has been silently doing nothing
-- as long as the API connects as `postgres` - a Postgres superuser
-- bypasses RLS by default, regardless of how many policies exist. This
-- migration, plus switching DB_USER on the API's Cloud Run service to
-- app_service, is what actually turns RLS on in practice.

SELECT set_config('migration.app_service_password', :'app_service_password', false);

DO $$
DECLARE
  pw TEXT := current_setting('migration.app_service_password');
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'app_service') THEN
    EXECUTE format('CREATE ROLE app_service WITH LOGIN PASSWORD %L NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS', pw);
  ELSE
    EXECUTE format('ALTER ROLE app_service WITH PASSWORD %L', pw);
  END IF;
END
$$;

GRANT USAGE ON SCHEMA employee TO app_service;
GRANT USAGE ON SCHEMA reference TO app_service;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA employee TO app_service;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA reference TO app_service;

-- Ensures tables created by future migrations are automatically
-- granted too, without needing to remember to GRANT each time.
ALTER DEFAULT PRIVILEGES IN SCHEMA employee GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_service;
ALTER DEFAULT PRIVILEGES IN SCHEMA reference GRANT SELECT, INSERT, UPDATE ON TABLES TO app_service;

-- Explicit, not just an oversight: app_service must never read the
-- credential store directly (Database Design - Common Platform
-- Standards, Section 4.6) - only AuthService's own login path touches
-- security.credential, and that's a separate concern from this role.
-- Guarded because the security schema is created by a separate Phase 2
-- migration and may not exist yet in every environment this runs in.
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_namespace WHERE nspname = 'security') THEN
    REVOKE ALL ON SCHEMA security FROM app_service;
  END IF;
END
$$;
