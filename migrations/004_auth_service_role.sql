-- Creates auth_service: a role scoped ONLY to reading security.credential
-- for the login flow. Run via the migration runner, same pattern as
-- 002_app_service_role.sql - reads AUTH_SERVICE_PASSWORD from the
-- environment via set_config().
--
-- WHY THIS IS A SEPARATE ROLE FROM app_service: AuthService.login()
-- needs to SELECT from security.credential, but app_service was
-- deliberately locked out of the entire security schema (002, and
-- Database Design - Common Platform Standards Section 4.6). Rather
-- than reopening that door, AuthService gets its own narrowly-scoped
-- connection that can read security.credential and nothing else - it
-- has no access to employee/reference schemas at all.

SELECT set_config('migration.auth_service_password', :'auth_service_password', false);

DO $$
DECLARE
  pw TEXT := current_setting('migration.auth_service_password');
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'auth_service') THEN
    EXECUTE format('CREATE ROLE auth_service WITH LOGIN PASSWORD %L NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS', pw);
  ELSE
    EXECUTE format('ALTER ROLE auth_service WITH PASSWORD %L', pw);
  END IF;
END
$$;

GRANT USAGE ON SCHEMA security TO auth_service;
GRANT SELECT ON security.credential TO auth_service;

-- Explicit, not an oversight: auth_service must never touch employee
-- or reference data - it exists solely to authenticate a login.
REVOKE ALL ON SCHEMA employee FROM auth_service;
REVOKE ALL ON SCHEMA reference FROM auth_service;
