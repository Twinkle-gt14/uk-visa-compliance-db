-- The CoS Details form (both Candidate Onboarding's own CoS step and
-- Pre-Employment Compliance Check's CoS step) has always had fields
-- for "Applicant is applying from", the system-determined CoS type,
-- genuine vacancy confirmation, and its confirmation date - but
-- employee.employee_cos_detail was never given columns for them, so
-- these 4 fields were silently never saved or returned by the API.
ALTER TABLE employee.employee_cos_detail
  ADD COLUMN applying_from TEXT,
  ADD COLUMN cos_type TEXT,
  ADD COLUMN genuine_vacancy_confirmed TEXT,
  ADD COLUMN genuine_vacancy_confirmed_date DATE;
