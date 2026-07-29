-- Leave module schema. Two tables:
--
--   reference.leave_type   - the tenant's configurable leave categories
--                            (today this lives ONLY in the frontend's
--                            localStorage - Settings > Leave Types /
--                            lib/leave-entitlements.ts. That's per-
--                            browser, not per-tenant, and invisible to
--                            the API. This table is the real,
--                            tenant-scoped source of truth going
--                            forward; the frontend should be switched
--                            to read/write it via the API in a later
--                            round instead of localStorage.)
--
--   leave.leave_request    - actual submitted leave requests, with a
--                            real approval workflow (pending / approved
--                            / rejected / cancelled). This is the piece
--                            that didn't exist at all before - Apply
--                            Leave only held requests in React state.
--
-- Column names/values are chosen to match the existing frontend types
-- exactly (lib/leave-entitlements.ts's LeaveEntitlement, lib/leave-
-- requests.ts's LeaveRequest) so the frontend can be wired to this API
-- later with a straight field-for-field mapping.

CREATE SCHEMA IF NOT EXISTS leave;

-- ---------------------------------------------------------------------
-- reference.leave_type
-- ---------------------------------------------------------------------
CREATE TABLE reference.leave_type (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  -- Stable slug so "annual-leave" / "sick-leave" can be referred to by
  -- code (proration rule, attendance-status mapping) without depending
  -- on the display name, which is user-editable in Settings.
  slug TEXT NOT NULL,
  name TEXT NOT NULL,
  category TEXT NOT NULL,
  paid_unpaid TEXT NOT NULL,
  annual_entitlement NUMERIC(5, 2) NOT NULL,
  carry_forward BOOLEAN NOT NULL DEFAULT false,
  max_carry_forward NUMERIC(5, 2) NOT NULL DEFAULT 0,
  is_selected BOOLEAN NOT NULL DEFAULT true,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_leave_type_tenant_slug UNIQUE (tenant_id, slug),
  CONSTRAINT ck_leave_type_category CHECK (category IN ('Statutory', 'Employer')),
  CONSTRAINT ck_leave_type_paid_unpaid CHECK (paid_unpaid IN ('Paid', 'Unpaid'))
);
CREATE INDEX idx_leave_type_tenant ON reference.leave_type(tenant_id);

ALTER TABLE reference.leave_type ENABLE ROW LEVEL SECURITY;
CREATE POLICY leave_type_tenant_isolation ON reference.leave_type
  USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);

-- ---------------------------------------------------------------------
-- leave.leave_request
-- ---------------------------------------------------------------------
CREATE TABLE leave.leave_request (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  employee_id UUID NOT NULL REFERENCES employee.employee_master(id),
  leave_type_id UUID NOT NULL REFERENCES reference.leave_type(id),
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  -- Simple inclusive calendar-day count ((end - start) + 1), matching
  -- the frontend's existing `noOfDays` calculation exactly (see Apply
  -- Leave page) - it does not exclude weekends or bank holidays. Kept
  -- consistent with the frontend rather than "more correct", so the
  -- number shown while applying never disagrees with what's stored.
  no_of_days NUMERIC(6, 2) NOT NULL,
  reason TEXT NOT NULL,
  contact_number TEXT NOT NULL,
  document_file_reference TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  submitted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  decided_at TIMESTAMPTZ,
  decided_by_name TEXT,
  decision_note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ck_leave_request_status CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled')),
  CONSTRAINT ck_leave_request_dates CHECK (end_date >= start_date)
);
CREATE INDEX idx_leave_request_employee ON leave.leave_request(employee_id, start_date, end_date);
CREATE INDEX idx_leave_request_tenant ON leave.leave_request(tenant_id);
CREATE INDEX idx_leave_request_status ON leave.leave_request(status);

ALTER TABLE leave.leave_request ENABLE ROW LEVEL SECURITY;
CREATE POLICY leave_request_tenant_isolation ON leave.leave_request
  USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);

-- Extend app_service's existing grants (same isolation model as
-- employee/reference/attendance) to cover the new schema/table.
GRANT USAGE ON SCHEMA leave TO app_service;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA leave TO app_service;
ALTER DEFAULT PRIVILEGES IN SCHEMA leave GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_service;

-- reference.leave_type specifically (not a blanket re-grant on the
-- whole reference schema, which migration 002 already covers at
-- SELECT/INSERT/UPDATE - DELETE is added here only for this table,
-- since removing a custom leave type is a legitimate Settings action
-- that department deletion, deliberately, still doesn't support).
GRANT SELECT, INSERT, UPDATE, DELETE ON reference.leave_type TO app_service;
