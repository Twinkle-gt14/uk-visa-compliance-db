/**
 * Real migration runner: tracks which migrations/*.sql files have
 * already been applied (in a schema_migrations table) and only runs
 * new ones, in filename order, each inside its own transaction.
 *
 * Deliberately uses its own, separate connection credentials
 * (MIGRATE_DB_USER, defaulting to postgres) rather than the app's
 * runtime DB_USER - migrations need to CREATE SCHEMA/ROLE/TABLE, which
 * the restricted app_service role must NOT be able to do. Keeping
 * these two credentials distinct is itself part of the hardening: the
 * running API never has schema-modification privileges.
 *
 * Usage:
 *   MIGRATE_DB_PASSWORD=... APP_SERVICE_PASSWORD=... node scripts/migrate.js
 */
const { Client } = require("pg");
const fs = require("fs");
const path = require("path");

const MIGRATIONS_DIR = path.join(__dirname, "..", "migrations");

async function main() {
  const client = new Client({
    host: process.env.DB_HOST || "127.0.0.1",
    port: Number(process.env.DB_PORT || 6432),
    user: process.env.MIGRATE_DB_USER || "postgres",
    password: process.env.MIGRATE_DB_PASSWORD,
    database: process.env.DB_NAME || "uk_visa_compliance",
  });

  await client.connect();
  console.log(`Connected as ${process.env.MIGRATE_DB_USER || "postgres"} to run migrations.`);

  await client.query(`
    CREATE TABLE IF NOT EXISTS public.schema_migrations (
      filename TEXT PRIMARY KEY,
      applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  `);

  const applied = new Set(
    (await client.query("SELECT filename FROM public.schema_migrations")).rows.map((r) => r.filename)
  );

  const files = fs
    .readdirSync(MIGRATIONS_DIR)
    .filter((f) => f.endsWith(".sql"))
    .sort();

  let ranAny = false;
  for (const file of files) {
    if (applied.has(file)) {
      console.log(`- ${file} (already applied, skipping)`);
      continue;
    }

    let sql = fs.readFileSync(path.join(MIGRATIONS_DIR, file), "utf8");

    // Migrations sometimes reference :'some_variable' in psql-variable-
    // substitution syntax (so the file also works if someone runs it
    // directly via psql -v) - substitute any such token here from the
    // correspondingly-named environment variable (upper-cased), so this
    // runner can execute any such migration without a new special case
    // each time one is added.
    const varMatches = [...sql.matchAll(/:'([a-z_]+)'/g)];
    for (const [token, varName] of varMatches) {
      const envName = varName.toUpperCase();
      const value = process.env[envName];
      if (!value) {
        throw new Error(`${file} requires ${envName} to be set - refusing to run without it.`);
      }
      const escaped = value.replace(/'/g, "''");
      sql = sql.replaceAll(token, `'${escaped}'`);
    }

    console.log(`\u2192 Applying ${file}...`);
    try {
      await client.query("BEGIN");
      await client.query(sql);
      await client.query("INSERT INTO public.schema_migrations (filename) VALUES ($1)", [file]);
      await client.query("COMMIT");
      console.log(`\u2713 ${file} applied.`);
      ranAny = true;
    } catch (err) {
      await client.query("ROLLBACK");
      console.error(`\u2717 ${file} FAILED - stopping here. Fix the error below and re-run; already-applied migrations will be skipped.`);
      throw err;
    }
  }

  if (!ranAny) {
    console.log("\nNothing new to apply - database is up to date.");
  }

  await client.end();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
