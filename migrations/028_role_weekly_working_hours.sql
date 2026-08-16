-- Settings > Role now also captures Weekly working hours - Candidate
-- Onboarding's Role Details panel shows it alongside the other role
-- fields (work location, duties, skills, salary, reporting line,
-- business justification) rather than it being typed in separately
-- per candidate under Employment terms.

ALTER TABLE reference.role
  ADD COLUMN weekly_working_hours TEXT;
