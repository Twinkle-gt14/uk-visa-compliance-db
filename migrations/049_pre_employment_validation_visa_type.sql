-- Settings > Pre-Employment Validation: a new "Visa Type" column so
-- each rule can be tagged as applying to the Skilled Worker or Global
-- Business Mobility route (same two options WorkStep's own
-- sponsorship_visa_route field offers, see migration 047). One-time
-- backfill below tags every existing row containing "GBM" in its
-- Checkpoint text as Global Business Mobility, everything else as
-- Skilled Worker - the same heuristic future uploads use by default
-- (see settings.service.ts's uploadPreEmploymentValidationRules).
ALTER TABLE reference.pre_employment_validation_rule
  ADD COLUMN visa_type TEXT;

UPDATE reference.pre_employment_validation_rule
  SET visa_type = CASE WHEN checkpoint ILIKE '%GBM%' THEN 'Global Business Mobility' ELSE 'Skilled Worker' END;
