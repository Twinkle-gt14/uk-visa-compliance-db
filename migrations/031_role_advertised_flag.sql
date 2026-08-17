-- Settings > Role now also captures "Was this role advertised?" -
-- feeds the Role & Recruitment genuine-vacancy record, alongside the
-- advertisement evidence documents added in migration 030.

ALTER TABLE reference.role
  ADD COLUMN advertised TEXT;
