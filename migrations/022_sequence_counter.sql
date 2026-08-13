-- 022_sequence_counter.sql
--
-- Generic per-tenant, per-sequence counter - Candidate ID (C000001,
-- C000002...) and Employee Number (E000001, E000002...) both need a
-- real gapless-enough sequential number, not the timestamp-based
-- genRef() already used for employee_reference_no. One small table
-- serves both (and any future sequence) rather than a dedicated
-- Postgres SEQUENCE per tenant, which doesn't fit the multi-tenant
-- RLS model used everywhere else in this schema.
CREATE TABLE reference.sequence_counter (
  tenant_id UUID NOT NULL,
  sequence_name TEXT NOT NULL,
  next_value INT NOT NULL DEFAULT 1,
  PRIMARY KEY (tenant_id, sequence_name)
);

ALTER TABLE reference.sequence_counter ENABLE ROW LEVEL SECURITY;
CREATE POLICY sequence_counter_tenant_isolation ON reference.sequence_counter
  USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);

GRANT SELECT, INSERT, UPDATE, DELETE ON reference.sequence_counter TO app_service;
