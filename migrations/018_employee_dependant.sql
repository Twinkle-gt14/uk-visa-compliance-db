-- 018_employee_dependant.sql
--
-- Fixes a real gap, not an enhancement: the Visa step's "Dependants
-- linked to this visa" table has been sending data to the API since
-- it was built, but there was never a table, DTO field, or service
-- logic on the backend to receive it - every save silently dropped
-- it, and every reload came back empty. Mirrors employee_rtw_check's
-- shape/RLS/grant pattern exactly (migrations/001_employee_schema.sql).

CREATE TABLE employee.employee_dependant (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  employee_id UUID NOT NULL REFERENCES employee.employee_master(id),
  name TEXT,
  relationship TEXT,
  date_of_birth DATE
);
CREATE INDEX idx_dependant_employee ON employee.employee_dependant(employee_id);

ALTER TABLE employee.employee_dependant ENABLE ROW LEVEL SECURITY;
CREATE POLICY employee_dependant_tenant_isolation ON employee.employee_dependant
  USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);

GRANT SELECT, INSERT, UPDATE, DELETE ON employee.employee_dependant TO app_service;
