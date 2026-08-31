/**
 * FULL DATA RESET - deletes every row of operational/candidate data
 * across the whole app (Candidate Onboarding, Employee Register,
 * Attendance, Leave, Pre-Employment Compliance) so you can start
 * completely fresh. Supersedes reset-employee-data.js, which only
 * covered a subset of these tables.
 *
 * This is NOT a migration - it does not belong in migrations/ and is
 * never run automatically. It's a deliberate, one-time destructive
 * action you run yourself, the same way you run migrations (same
 * Cloud SQL Proxy, same MIGRATE_DB_USER/MIGRATE_DB_PASSWORD).
 *
 * PRESERVED (every master/reference table uploaded or configured
 * through Settings, plus its own upload-audit trail - none of this is
 * per-candidate data, so none of it is touched):
 *   - reference.role (Settings > Role, formerly "Position")
 *   - reference.visa_type, reference.work_location, reference.holiday
 *   - reference.employer_profile (incl. its email_domain login setting)
 *   - reference.healthcare_pay_band, reference.education_pay_scale
 *   - reference.leave_type, reference.payslip_component
 *   - reference.pre_employment_validation_rule (Settings > Pre-Employment Validation)
 *   - reference.employee_compliance_upload_row (Settings > Compliance > Employee Compliance)
 *   - reference.soc_occupation_master (Settings > SOC 2020 Framework)
 *   - reference.uk_jurisdiction
 *   - compliance.skilled_worker_occupation_master
 *   - compliance.isl_version, compliance.isl_occupation,
 *     compliance.isl_jurisdiction_applicability, compliance.isl_version_record
 *   - compliance.import_batch, compliance.import_batch_record (the
 *     upload history behind the master-data tables above)
 *   - security.credential rows with role = 'hr_admin' (i.e. every
 *     admin login) - deliberately never touched, see below
 *
 * DELETED (every row of candidate/employee-specific operational
 * data):
 *   - every employee.* child table, then employee.employee_master
 *   - reference.department (created per-tenant by the app itself, not
 *     Settings master data - has a required FK from employee_master)
 *   - attendance.attendance_record, leave.leave_request
 *   - compliance.sponsorship_assessment
 *   - compliance.supporting_document - ONLY rows with employee_id set
 *     (rows with role_id set are Settings > Role advertisement
 *     evidence, not candidate data, and are left alone)
 *   - security.credential - ONLY rows with employee_id set (a
 *     candidate's own self-service login). role = 'hr_admin' rows
 *     (employee_id NULL) are never touched - deleting those would
 *     lock every admin out of the app.
 *   - reference.sequence_counter - so Candidate ID / Employee Number
 *     numbering (C000001, E000001...) restarts from 1
 *
 * A note on security.credential: this table isn't defined in this
 * repo's own migrations (it's owned by the Auth Service - see
 * migrations/004_auth_service_role.sql and
 * migrations/024_employee_login_support.sql). It's included here only
 * because employee.employee_master can't be deleted while a
 * credential row still references it via employee_id (no ON DELETE
 * CASCADE on that FK) - not because this script otherwise manages
 * logins. If your Auth Service's schema for this table ever changes
 * shape, re-check this step still matches.
 *
 * Deletion order matters throughout: every child table goes before
 * its parent (employee.* children before employee_master;
 * security.credential and compliance.supporting_document's
 * employee-owned rows before employee_master; employee_master before
 * reference.department). Everything runs inside a single transaction:
 * if anything fails partway through, nothing is deleted at all.
 *
 * Usage (requires typing --confirm, not just running the command):
 *   DB_HOST=127.0.0.1 DB_PORT=5433 MIGRATE_DB_USER=postgres MIGRATE_DB_PASSWORD=... node scripts/reset-all-data.js --confirm
 */
const { Client } = require("pg");

const CONFIRMED = process.argv.includes("--confirm");

// Simple, unconditional DELETE FROM - order matters (children first).
const FULL_DELETE_TABLES = [
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
  "employee.employee_dependant",
  "employee.idempotency_key",
  "attendance.attendance_record",
  "leave.leave_request",
  "compliance.sponsorship_assessment",
];

// DELETE FROM ... WHERE <condition> - these tables also hold rows
// that belong to preserved Settings master data, so only the
// candidate-owned rows are removed.
const CONDITIONAL_DELETES = [
  { table: "compliance.supporting_document", where: "employee_id IS NOT NULL" },
  { table: "security.credential", where: "employee_id IS NOT NULL" },
];

// Deleted last, in this order: employee_master's own children (both
// lists above) must be gone first, then employee_master itself, then
// department (employee_master has a required FK to it), then the
// numbering counters.
const FINAL_TABLES = ["employee.employee_master", "reference.department", "reference.sequence_counter"];

async function countRows(client, table, where) {
  const sql = where ? `SELECT count(*)::int AS n FROM ${table} WHERE ${where}` : `SELECT count(*)::int AS n FROM ${table}`;
  const result = await client.query(sql);
  return result.rows[0].n;
}

async function main() {
  if (!CONFIRMED) {
    console.error("Refusing to run without --confirm. This permanently deletes ALL candidate/employee, attendance, leave, and compliance data.");
    console.error("Every Settings-uploaded master/reference table (Role, Visa Type, Work Location, Holidays, Employer Profile, SOC 2020 Framework, Skilled Worker Occupation Master, ISL, Pre-Employment Validation rules, Employee Compliance checklist upload, and all hr_admin logins) is left untouched.");
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

  const allTargets = [
    ...FULL_DELETE_TABLES.map((table) => ({ table })),
    ...CONDITIONAL_DELETES,
    ...FINAL_TABLES.map((table) => ({ table })),
  ];

  console.log("\nBefore:");
  for (const { table, where } of allTargets) {
    const n = await countRows(client, table, where);
    console.log(`  ${table}${where ? ` (${where})` : ""}: ${n}`);
  }

  try {
    await client.query("BEGIN");

    for (const table of FULL_DELETE_TABLES) {
      const result = await client.query(`DELETE FROM ${table}`);
      console.log(`Deleted ${result.rowCount} row(s) from ${table}`);
    }

    for (const { table, where } of CONDITIONAL_DELETES) {
      const result = await client.query(`DELETE FROM ${table} WHERE ${where}`);
      console.log(`Deleted ${result.rowCount} row(s) from ${table} (${where})`);
    }

    for (const table of FINAL_TABLES) {
      const result = await client.query(`DELETE FROM ${table}`);
      console.log(`Deleted ${result.rowCount} row(s) from ${table}`);
    }

    await client.query("COMMIT");
    console.log("\n\u2713 Committed - all listed tables cleared. Every Settings master table was left untouched.");
  } catch (err) {
    await client.query("ROLLBACK");
    console.error("\n\u2717 FAILED and rolled back - nothing was deleted. Error below:");
    throw err;
  }

  console.log("\nAfter:");
  for (const { table, where } of allTargets) {
    const n = await countRows(client, table, where);
    console.log(`  ${table}${where ? ` (${where})` : ""}: ${n}`);
  }

  await client.end();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
