-- SOC Details' "Guaranteed basic gross pay" field used to be entirely
-- client-side/ephemeral - typed in, shown against the salary
-- assessment reference table, but never actually saved anywhere, so
-- it reverted to blank every time the record was reopened. Same
-- pattern as salary_offered (migration 038): a plain nullable TEXT
-- column on employee_master, shared by both Candidate Onboarding and
-- Employee Register since they're the same underlying row.
ALTER TABLE employee.employee_master
  ADD COLUMN guaranteed_basic_gross_pay TEXT;
