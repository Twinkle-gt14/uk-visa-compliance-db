-- Settings > Role now accepts advertisement evidence documents (one
-- or more per Role), alongside "Was this role advertised?" - so
-- compliance.supporting_document needs to support being owned by a
-- Role, not just an Employee. employee_id becomes nullable and a new
-- role_id column is added, with a CHECK ensuring every document is
-- attached to exactly one of the two owners - never both, never
-- neither.

ALTER TABLE compliance.supporting_document
  ALTER COLUMN employee_id DROP NOT NULL,
  ADD COLUMN role_id UUID REFERENCES reference.role(id),
  ADD CONSTRAINT chk_supporting_document_single_owner
    CHECK ((employee_id IS NOT NULL) <> (role_id IS NOT NULL));

CREATE INDEX idx_supporting_document_role ON compliance.supporting_document(role_id);
