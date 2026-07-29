-- Attendance module schema. Per Employee Module Technical Design's own
-- pattern: only actual, explicit attendance entries get a row here -
-- "Weekly Off" and "Bank Holiday" are NOT stored per day. Those are
-- derived (day-of-week, and a holiday calendar that doesn't have its
-- own backend yet - see Open Points) - this table only records what a
-- person actually did on a working day: present/remote/leave/sick
-- leave/absent, with real check-in/check-out times where relevant.
--
-- This is a deliberate change from the old frontend mock, which
-- generated a full 7-status record for every single day. A real
-- backend has no legitimate data for a day nobody has recorded yet -
-- showing "Present" by default for an untouched day would be
-- fabricating attendance, not displaying it.

CREATE SCHEMA IF NOT EXISTS attendance;

CREATE TABLE attendance.attendance_record (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  employee_id UUID NOT NULL REFERENCES employee.employee_master(id),
  record_date DATE NOT NULL,
  status TEXT NOT NULL,
  check_in TIME,
  check_out TIME,
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_attendance_employee_date UNIQUE (tenant_id, employee_id, record_date),
  CONSTRAINT ck_attendance_status CHECK (status IN ('present', 'remote', 'leave', 'sick-leave', 'absent'))
);

CREATE INDEX idx_attendance_employee_date ON attendance.attendance_record(employee_id, record_date);
CREATE INDEX idx_attendance_tenant ON attendance.attendance_record(tenant_id);

ALTER TABLE attendance.attendance_record ENABLE ROW LEVEL SECURITY;
CREATE POLICY attendance_record_tenant_isolation ON attendance.attendance_record
  USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);

-- Extend app_service's existing grants (Technical Design Document,
-- Section 4.2) to cover this new schema - same role, same isolation
-- model as employee/reference, just a new schema to allow.
GRANT USAGE ON SCHEMA attendance TO app_service;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA attendance TO app_service;
ALTER DEFAULT PRIVILEGES IN SCHEMA attendance GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_service;
