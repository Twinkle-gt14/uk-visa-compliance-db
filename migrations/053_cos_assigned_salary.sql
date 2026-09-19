-- The CoS form's "Assigned salary" and "Pay frequency" were only ever
-- held in the front-end form state and never saved. Persisting them so
-- Sponsor Employee Compliance can compare the employee's current
-- salary (employee_master.salary_offered) against the salary stated on
-- their CoS.
ALTER TABLE employee.employee_cos_detail
  ADD COLUMN cos_assigned_salary TEXT,
  ADD COLUMN cos_pay_frequency TEXT;
