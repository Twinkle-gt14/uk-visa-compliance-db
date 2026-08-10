-- Adds Sponsor Name alongside the existing Sponsor Licence Number on
-- reference.employer_profile. Both are organisation-level (one value
-- per tenant, not per employee/candidate) - the Candidate Onboarding
-- CoS step reads these rather than collecting them per candidate.
ALTER TABLE reference.employer_profile
  ADD COLUMN sponsor_name TEXT;
