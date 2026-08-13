-- 020_employee_onboarded_flag.sql
--
-- Candidate Onboarding, Pre-Employment Compliance Check, and Employee
-- Register have all been reading the same employee.employee_master
-- rows with no field distinguishing "still a candidate" from
-- "actually onboarded as an employee" - every candidate has always
-- shown up in Employee Register too. This is the real fix, not a
-- cosmetic one: Employee Onboarding's "Onboard Employee" action needs
-- somewhere to record that transition actually happened.
ALTER TABLE employee.employee_master
  ADD COLUMN is_onboarded BOOLEAN NOT NULL DEFAULT false;
