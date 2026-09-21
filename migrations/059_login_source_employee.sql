-- A login created for an employee under another role (e.g. hr.e000020@company) is not the employee's own login,
-- so it can't use credential.employee_id (unique). This records which employee it belongs to, so it stops working
-- automatically when that employee is no longer Active.
ALTER TABLE security.credential ADD COLUMN source_employee_id UUID;
CREATE INDEX idx_credential_source_employee ON security.credential(source_employee_id) WHERE source_employee_id IS NOT NULL;

-- Existing role logins follow the "<role>.<employee id>@domain" pattern.
UPDATE security.credential c
SET source_employee_id = m.id
FROM employee.employee_master m
WHERE c.source_employee_id IS NULL AND c.employee_id IS NULL AND c.tenant_id = m.tenant_id
  AND lower(c.email) LIKE '%.' || lower(m.employee_id_label) || '@%';
