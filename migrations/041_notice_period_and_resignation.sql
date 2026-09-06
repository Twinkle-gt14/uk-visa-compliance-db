-- reference.notice_period - Settings > HR > Notice Period. Same
-- (tenant_id, id, name) shape as the other simple reference lists
-- (department/role/visa_type/work_location), plus one extra numeric
-- column (notice_days), which is why this gets its own small
-- service/controller methods rather than reusing the generic
-- listSimple/createSimple/updateSimple helpers those share (same
-- reasoning as reference.work_location's own bespoke methods, which
-- also carry one extra field - jurisdiction_id - beyond the generic
-- shape).
--
-- The Resignation page (employee.resignation_request below) reads
-- whichever row was created first as "the" notice period currently in
-- effect - there's no per-employee or per-policy assignment yet, so
-- multiple rows are supported by this CRUD (Add/Edit/Delete all work
-- on any row) but only that first one actually drives the tentative
-- last-date calculation today.
CREATE TABLE reference.notice_period (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  name TEXT NOT NULL,
  notice_days INTEGER NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_notice_period_tenant_name UNIQUE (tenant_id, name),
  CONSTRAINT ck_notice_period_days_positive CHECK (notice_days > 0)
);
CREATE INDEX idx_notice_period_tenant ON reference.notice_period(tenant_id, created_at);

ALTER TABLE reference.notice_period ENABLE ROW LEVEL SECURITY;
CREATE POLICY notice_period_tenant_isolation ON reference.notice_period
  USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);

GRANT SELECT, INSERT, UPDATE, DELETE ON reference.notice_period TO app_service;

-- employee.resignation_request - an employee's own resignation,
-- awaiting an HR decision. Deliberately its own table rather than
-- reusing leave.leave_request (a resignation isn't a leave, and has
-- no leave_type/date-range/attendance-writing side effects to share
-- with that table) - same one-table-per-distinct-workflow approach as
-- employee.employee_change_request (038/039). notice_days and
-- tentative_last_date are snapshotted at submission time from
-- whatever Settings > HR > Notice Period showed then, so a later
-- change to that setting doesn't retroactively alter an
-- already-submitted request's own figures.
CREATE TABLE employee.resignation_request (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  employee_id UUID NOT NULL REFERENCES employee.employee_master(id),
  reason TEXT,
  notice_days INTEGER NOT NULL,
  tentative_last_date DATE NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  submitted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  decided_at TIMESTAMPTZ,
  decided_by_name TEXT,
  decision_note TEXT,
  CONSTRAINT ck_resignation_request_status CHECK (status IN ('pending', 'approved', 'rejected'))
);
CREATE INDEX idx_resignation_request_employee ON employee.resignation_request(employee_id, submitted_at DESC);
CREATE INDEX idx_resignation_request_status ON employee.resignation_request(tenant_id, status, submitted_at DESC);

ALTER TABLE employee.resignation_request ENABLE ROW LEVEL SECURITY;
CREATE POLICY resignation_request_tenant_isolation ON employee.resignation_request
  USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);

GRANT SELECT, INSERT, UPDATE, DELETE ON employee.resignation_request TO app_service;
