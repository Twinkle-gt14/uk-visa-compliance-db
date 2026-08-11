-- Candidate ID (manually entered on the Candidate Onboarding wizard) is
-- a distinct field from Employee ID (entered on the Employee Register
-- screen) - both live on the same employee_master record but are
-- captured independently, so each needs its own column.
ALTER TABLE employee.employee_master
  ADD COLUMN candidate_id_label TEXT; -- the free-text "Candidate ID" field the Candidate Onboarding wizard captures
