-- reference.position was a bare name-only reference table (matching
-- Department, Visa Type, etc.). Settings > Position now needs to
-- capture a full role profile - the same fields Candidate Onboarding's
-- Role Details step needs to look up once a position is selected
-- there (main duties, required skills, salary range, reporting line,
-- work location(s), business justification) - so this is now its own
-- richer master record, not a plain name list.

ALTER TABLE reference.position
  ADD COLUMN work_location TEXT,
  ADD COLUMN main_duties TEXT,
  ADD COLUMN required_skills TEXT,
  ADD COLUMN salary_range TEXT,
  ADD COLUMN reporting_line TEXT,
  ADD COLUMN business_justification TEXT;
