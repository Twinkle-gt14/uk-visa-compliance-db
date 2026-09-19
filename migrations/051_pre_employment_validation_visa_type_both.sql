-- Rule ID C14 (CoS & Fees) and R1 (Role & Recruitment) genuinely apply
-- to both sponsorship routes - their Checkpoint text just happens to
-- mention "GBM" alongside "Skilled Worker" (e.g. R1: "Skilled Worker
-- Table 1/1a; GBM Table 2/2b/3"), which is why migration 049's
-- GBM-in-Checkpoint heuristic mistagged them as Global Business
-- Mobility only. Corrected here to the combined value both routes'
-- names joined by ", " - ImmigrationAssessmentStep.tsx's own filter
-- treats a visa_type that *contains* the candidate's chosen route
-- (not just an exact match) as applicable, so this one row shows for
-- either route rather than needing two duplicate rows.
UPDATE reference.pre_employment_validation_rule
  SET visa_type = 'Skilled Worker, Global Business Mobility'
  WHERE (category = 'CoS & Fees' AND rule_id = 'C14')
     OR (category = 'Role & Recruitment' AND rule_id = 'R1');
