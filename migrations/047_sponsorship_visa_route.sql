-- Candidate Onboarding's Work Details step: once a non-UK-citizen/non-
-- ILR candidate is marked "To be Sponsored", HR picks the intended
-- sponsorship visa route (Skilled Worker vs Global Business Mobility)
-- right there, before Sponsorship Assessment/CoS/Visa exist yet. Stored
-- as its own column rather than reusing employee_visa_detail.visa_type,
-- which is the actual granted visa recorded much later in the pipeline.
ALTER TABLE employee.employee_master
  ADD COLUMN sponsorship_visa_route TEXT;
