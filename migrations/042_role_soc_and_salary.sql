-- SOC Details used to be its own step in Candidate Onboarding/Employee
-- Register, where a SOC 2020 code, guaranteed basic gross pay and the
-- Health & Care flag were picked per-candidate. That step is removed -
-- these are role-level facts (every hire into the same role shares the
-- same occupation classification and pay band), so they move to
-- Settings > Role instead, alongside the rest of the role profile
-- (migrations 026/027/028/031).
ALTER TABLE reference.role
  ADD COLUMN soc_number TEXT,
  ADD COLUMN guaranteed_basic_gross_pay TEXT,
  ADD COLUMN is_health_and_care_role TEXT;
