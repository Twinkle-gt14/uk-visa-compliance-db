-- Personal's new "Is ILR / Settled Status" checkbox (defaults to
-- unchecked) - same effect as is_uk_citizen on whether Sponsorship
-- status, SOC Code and the Immigration & Sponsorship tab apply.
ALTER TABLE employee.employee_master
  ADD COLUMN is_ilr_settled BOOLEAN NOT NULL DEFAULT false;
