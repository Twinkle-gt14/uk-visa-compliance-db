-- Personal's new "Is a UK Citizen?" checkbox (defaults to Yes) - drives
-- whether Sponsorship status shows at all on Work Details, since only
-- a non-UK-citizen can need sponsorship.
ALTER TABLE employee.employee_master
  ADD COLUMN is_uk_citizen BOOLEAN NOT NULL DEFAULT true;
