/**
 * Proves, against a real database, that:
 *  1. Connecting as app_service + a tenant A context can see tenant A's
 *     own data.
 *  2. Connecting as app_service + a tenant B context CANNOT see tenant
 *     A's data - the actual point of Row-Level Security.
 *  3. Connecting as postgres (superuser) bypasses RLS entirely - this
 *     is expected Postgres behaviour, documented here as a reminder of
 *     exactly why the API must never connect as postgres in production.
 *
 * Usage:
 *   MIGRATE_DB_PASSWORD=... APP_SERVICE_PASSWORD=... node scripts/test-rls-isolation.js
 */
const { Client } = require("pg");
const crypto = require("crypto");

async function asAdmin() {
  const client = new Client({
    host: process.env.DB_HOST || "127.0.0.1",
    port: Number(process.env.DB_PORT || 6432),
    user: process.env.MIGRATE_DB_USER || "postgres",
    password: process.env.MIGRATE_DB_PASSWORD,
    database: process.env.DB_NAME || "uk_visa_compliance",
  });
  await client.connect();
  return client;
}

async function asAppService() {
  const client = new Client({
    host: process.env.DB_HOST || "127.0.0.1",
    port: Number(process.env.DB_PORT || 6432),
    user: "app_service",
    password: process.env.APP_SERVICE_PASSWORD,
    database: process.env.DB_NAME || "uk_visa_compliance",
  });
  await client.connect();
  return client;
}

function fail(message) {
  console.error(`\u2717 FAIL: ${message}`);
  process.exitCode = 1;
}
function pass(message) {
  console.log(`\u2713 PASS: ${message}`);
}

async function main() {
  const tenantA = crypto.randomUUID();
  const tenantB = crypto.randomUUID();

  const admin = await asAdmin();

  // Seed one department and one employee for tenant A only, using the
  // admin connection (bypasses RLS, which is fine for test setup).
  const dept = await admin.query(
    "INSERT INTO reference.department (tenant_id, name) VALUES ($1, 'RLS Test Dept') RETURNING id",
    [tenantA]
  );
  await admin.query(
    `INSERT INTO employee.employee_master
      (tenant_id, employee_reference_no, first_name, last_name, date_of_birth, job_title, department_id, date_of_joining)
     VALUES ($1, 'RLS-TEST-001', 'RlsTest', 'Employee', '1990-01-01', 'Tester', $2, '2024-01-01')`,
    [tenantA, dept.rows[0].id]
  );
  console.log(`Seeded 1 employee for tenant A (${tenantA}). Tenant B (${tenantB}) has no data.\n`);

  // --- Test 1: app_service + tenant A context sees tenant A's row ---
  const asA = await asAppService();
  await asA.query("BEGIN");
  await asA.query("SELECT set_config('app.current_tenant_id', $1, true)", [tenantA]);
  const resA = await asA.query("SELECT count(*)::int AS n FROM employee.employee_master WHERE employee_reference_no = 'RLS-TEST-001'");
  await asA.query("COMMIT");
  await asA.end();

  if (resA.rows[0].n === 1) {
    pass("app_service + tenant A context can see tenant A's own row");
  } else {
    fail(`app_service + tenant A context saw ${resA.rows[0].n} rows, expected 1`);
  }

  // --- Test 2: app_service + tenant B context CANNOT see tenant A's row - the actual RLS guarantee ---
  const asB = await asAppService();
  await asB.query("BEGIN");
  await asB.query("SELECT set_config('app.current_tenant_id', $1, true)", [tenantB]);
  const resB = await asB.query("SELECT count(*)::int AS n FROM employee.employee_master WHERE employee_reference_no = 'RLS-TEST-001'");
  await asB.query("COMMIT");
  await asB.end();

  if (resB.rows[0].n === 0) {
    pass("app_service + tenant B context CANNOT see tenant A's row (RLS is enforcing isolation)");
  } else {
    fail(`app_service + tenant B context saw ${resB.rows[0].n} rows belonging to tenant A - RLS ISOLATION IS BROKEN`);
  }

  // --- Test 3: document (not endorse) that a superuser bypasses RLS ---
  const resSuper = await admin.query("SELECT count(*)::int AS n FROM employee.employee_master WHERE employee_reference_no = 'RLS-TEST-001'");
  if (resSuper.rows[0].n === 1) {
    console.log(
      "\u2139 INFO: connecting as a superuser (postgres) sees the row regardless of tenant context - " +
        "expected Postgres behaviour, and exactly why the API must never use this connection in production."
    );
  }

  // Cleanup
  await admin.query("DELETE FROM employee.employee_master WHERE employee_reference_no = 'RLS-TEST-001'");
  await admin.query("DELETE FROM reference.department WHERE id = $1", [dept.rows[0].id]);
  await admin.end();

  if (process.exitCode === 1) {
    console.error("\nRLS isolation test FAILED - do not deploy until this passes.");
  } else {
    console.log("\nAll RLS isolation checks passed.");
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
