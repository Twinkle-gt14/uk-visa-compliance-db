-- Candidate Onboarding's "Joining date" is renamed to "Proposed joining
-- date" and split into its own column - date_of_joining is now solely
-- the actual joining date, relabeled "Actual Joining date" in Employee
-- Register. The two can genuinely differ once someone's actually
-- onboarded (a proposed date from hiring vs. the real day they started).
ALTER TABLE employee.employee_master
  ADD COLUMN proposed_joining_date DATE;
