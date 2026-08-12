/**
 * ONE-OFF DATA RESET - deletes every candidate/employee record and
 * every department entry, and everything that hangs off an employee
 * (contact details, visa/CoS/RTW/passport/education/bank/documents,
 * attendance records, leave requests, sponsorship assessments).
 *
 * This is NOT a migration - it does not belong in migrations/ and is
 * never run automatically. It's a deliberate, one-time destructive
 * action you run yourself, the same way you run migrations (same
 * Cloud SQL Proxy, same MIGRATE_DB_USER/MIGRATE_DB_PASSWORD).
 *
 * Explicitly NOT touched: Work Location, Position, Visa Type,
 * Holidays, Employer profile, SOC2020 Framework (soc_occupation_master),
 * Skilled Worker Occupation Master data, import batches, healthcare/
 * education pay reference data, users/logins.
 *
 * Deletion order matters - employee_master has a required FK to
 * department, and several tables have a required FK to employee_master,
 * so children must go first, employee_master second, department last.
 * Everything runs inside a single transaction: if anything fails
 * partway through, nothing is deleted at all.
 *
 * Usage (requires typing CONFIRM, not just running the command):
 *   DB_HOST=127.0.0.1 DB_PORT=5433 MIGRATE_DB_USER=postgres MIGRATE_DB_PASSWORD=... node scripts/reset-employee-data.js --confirm
 */
const { Client } = require("pg");

const CONFIRMED = process.argv.includes("--confirm");

const CHILD_TABLES = [
  "employee.employee_contact_detail",
  "employee.employee_emergency_contact",
  "employee.employee_bank_detail",
  "employee.employee_qualification",
  "employee.employee_certification",
  "employee.employee_passport_detail",
  "employee.employee_visa_detail",
  "employee.employee_cos_detail",
  "employee.employee_rtw_check",
  "employee.employee_document",
  "employee.idempotency_key",
  "attendance.attendance_record",
  "leave.leave_request",
  "compliance.sponsorship_assessment",
];

async function countRows(client, table) {
  const result = await client.query(`SELECT count(*)::int AS n FROM ${table}`);
  return result.rows[0].n;
}

async function main() {
  if (!CONFIRMED) {
    console.error("Refusing to run without --confirm. This permanently deletes all candidate/employee and department data.");
    console.error("Re-run with --confirm once you're sure.");
    process.exit(1);
  }

  const client = new Client({
    host: process.env.DB_HOST || "127.0.0.1",
    port: Number(process.env.DB_PORT || 6432),
    user: process.env.MIGRATE_DB_USER || "postgres",
    password: process.env.MIGRATE_DB_PASSWORD,
    database: process.env.DB_NAME || "uk_visa_compliance",
  });

  await client.connect();
  console.log(`Connected as ${process.env.MIGRATE_DB_USER || "postgres"}.`);

  console.log("\nBefore:");
  const before = {};
  for (const table of [...CHILD_TABLES, "employee.employee_master", "reference.department"]) {
    before[table] = await countRows(client, table);
    console.log(`  ${table}: ${before[table]}`);
  }

  try {
    await client.query("BEGIN");

    for (const table of CHILD_TABLES) {
      const result = await client.query(`DELETE FROM ${table}`);
      console.log(`Deleted ${result.rowCount} row(s) from ${table}`);
    }

    const masterResult = await client.query("DELETE FROM employee.employee_master");
    console.log(`Deleted ${masterResult.rowCount} row(s) from employee.employee_master`);

    const deptResult = await client.query("DELETE FROM reference.department");
    console.log(`Deleted ${deptResult.rowCount} row(s) from reference.department`);

    await client.query("COMMIT");
    console.log("\n\u2713 Committed - all listed tables cleared.");
  } catch (err) {
    await client.query("ROLLBACK");
    console.error("\n\u2717 FAILED and rolled back - nothing was deleted. Error below:");
    throw err;
  }

  console.log("\nAfter:");
  for (const table of [...CHILD_TABLES, "employee.employee_master", "reference.department"]) {
    const n = await countRows(client, table);
    console.log(`  ${table}: ${n}`);
  }

  await client.end();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
