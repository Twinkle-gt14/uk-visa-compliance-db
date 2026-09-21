-- Former employees who left more than 5 years ago can be moved to cold storage: they are kept (nothing is
-- deleted) but no longer appear in Former Employees or the Employee Register lists.
ALTER TABLE employee.employee_master ADD COLUMN cold_storage_at TIMESTAMPTZ;
CREATE INDEX idx_employee_master_cold_storage ON employee.employee_master(tenant_id) WHERE cold_storage_at IS NOT NULL;
