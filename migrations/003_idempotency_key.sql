-- Supports idempotent employee creation: a client-supplied
-- Idempotency-Key header lets a retried POST /employees (e.g. after a
-- timeout where the client never saw the response) return the
-- original result instead of creating a second record.
CREATE TABLE employee.idempotency_key (
  tenant_id UUID NOT NULL,
  idempotency_key TEXT NOT NULL,
  employee_id UUID NOT NULL REFERENCES employee.employee_master(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, idempotency_key)
);

ALTER TABLE employee.idempotency_key ENABLE ROW LEVEL SECURITY;
CREATE POLICY idempotency_key_tenant_isolation ON employee.idempotency_key
  USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);
