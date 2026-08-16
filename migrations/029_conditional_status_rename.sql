-- "Transitional" is being retired as its own status value - the app
-- now uses "Conditional" for every legacy/transitional-rule table
-- (Table 1a, 2aa, 2a, 3a), matching the SOC Details stepper's
-- eligibility badge wording. "Conditional" already existed as an
-- enum value (compliance.skilled_worker_occupation_master.status has
-- no DB-level CHECK constraint, just a documenting comment - see
-- migration 013), so this is a data rename only, not a schema change.

UPDATE compliance.skilled_worker_occupation_master
SET status = 'Conditional', updated_at = now()
WHERE status = 'Transitional';
