-- Employee self-service approval workflow.
--
-- When an HR Admin edits an Active employee record, the change applies
-- immediately, exactly as before - no approval needed for an HR action.
-- When the employee themselves edits their own record (a genuinely new
-- capability as of this migration; PATCH /employee/:id was previously
-- HR-only), the change is captured here instead of being written
-- straight to employee_master, and only takes effect once an HR Admin
-- approves it. The employee_master row is left completely untouched
-- until that approval happens, so "what the record currently shows"
-- and "what's pending" never get confused with each other.
--
-- One header row per submitted edit (so a single Save that touches
-- several fields on one step is approved/rejected as one unit, not
-- field-by-field), with one item row per field that actually changed.
CREATE TABLE employee.employee_change_request (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  employee_id UUID NOT NULL REFERENCES employee.employee_master(id),
  status TEXT NOT NULL DEFAULT 'Pending', -- 'Pending' | 'Approved' | 'Rejected'
  requested_by TEXT, -- the employee's email/name at the time of the request
  requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  reviewed_by TEXT,
  reviewed_at TIMESTAMPTZ,
  review_note TEXT
);
CREATE INDEX idx_employee_change_request_employee ON employee.employee_change_request(employee_id, requested_at DESC);
CREATE INDEX idx_employee_change_request_status ON employee.employee_change_request(tenant_id, status, requested_at DESC);

-- Same category/field_label/old_value/new_value shape as
-- employee_change_history (038), deliberately - once a request is
-- approved, its items are applied and logged into that same history
-- table, so the two need to already speak the same language rather
-- than requiring a translation step at approval time.
CREATE TABLE employee.employee_change_request_item (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id UUID NOT NULL REFERENCES employee.employee_change_request(id) ON DELETE CASCADE,
  category TEXT NOT NULL,
  field_key TEXT NOT NULL, -- the EmployeeUpsertDto key, e.g. "jobTitle" - needed to actually apply the change on approval, unlike history which only ever displays field_label
  field_label TEXT NOT NULL,
  old_value TEXT,
  new_value TEXT
);
CREATE INDEX idx_employee_change_request_item_request ON employee.employee_change_request_item(request_id);
