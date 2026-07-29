# DB layer - uk_visa_compliance

This is the third tier: Frontend -> API layer -> **DB layer** (Cloud SQL
Postgres). It's a standalone project, deliberately separate from
`api-service` - the schema has its own version history and lifecycle,
independent of whichever service happens to run a migration.

## What's here

- `migrations/*.sql` - numbered, sequential schema migrations, tracked
  via a `schema_migrations` table (applied automatically, in order,
  exactly once - see `scripts/migrate.js`).
- `scripts/migrate.js` - the migration runner.
- `scripts/test-rls-isolation.js` - proves Row-Level Security actually
  isolates tenants (not just that policies exist on paper).

## Running a migration

Via the Cloud SQL Auth Proxy (same as always):

```powershell
.\cloud-sql-proxy.exe --port 5433 uk-visa-compliance-dev:asia-south1:uk-visa-compliance-db
```

Then, in a separate terminal, from this folder:

```powershell
cd db
npm install
$env:DB_HOST="127.0.0.1"; $env:DB_PORT="5433"; $env:DB_NAME="uk_visa_compliance"
$env:MIGRATE_DB_USER="postgres"; $env:MIGRATE_DB_PASSWORD="<postgres admin password>"
# Only needed the first time a migration creates/changes a role's password:
$env:APP_SERVICE_PASSWORD="<app_service password>"
$env:AUTH_SERVICE_PASSWORD="<auth_service password>"
npm run migrate
```

## Roles this schema expects to exist

| Role | Used by | Access |
|---|---|---|
| `postgres` | Migrations only, never the running app | Full superuser - **never** used by api-service |
| `app_service` | api-service's Employee/Attendance modules | `employee`, `reference`, `attendance` schemas; RLS-scoped; no access to `security` |
| `auth_service` | api-service's Auth module only | `security.credential` (read-only); no access to `employee`/`reference`/`attendance` |

## Adding a new migration

Add a new `NNN_description.sql` file (next number in sequence), run
`npm run migrate` - it applies only what's new, tracked in
`schema_migrations`, and is safe to re-run (already-applied migrations
are skipped).
