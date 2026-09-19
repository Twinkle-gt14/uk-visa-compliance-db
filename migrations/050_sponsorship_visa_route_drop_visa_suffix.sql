-- One-time cleanup: sponsorship_visa_route (migration 047) used to
-- store "Skilled Worker Visa" / "Global Business Mobility Visa" (the
-- radio's own label text). Dropped the trailing " Visa" so the stored
-- value matches visa_type on reference.pre_employment_validation_rule
-- (migration 049: "Skilled Worker" / "Global Business Mobility") and
-- the two can be compared directly. WorkStep.tsx's radio group now
-- saves the trimmed value too - its label still reads "... Visa" for
-- clarity, only the stored value changed.
UPDATE employee.employee_master
  SET sponsorship_visa_route = 'Skilled Worker'
  WHERE sponsorship_visa_route = 'Skilled Worker Visa';

UPDATE employee.employee_master
  SET sponsorship_visa_route = 'Global Business Mobility'
  WHERE sponsorship_visa_route = 'Global Business Mobility Visa';
