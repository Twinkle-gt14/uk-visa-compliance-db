-- "British employee" toggle removed from Work Details (front-end and
-- api-service) - dropping the now-unused column it was persisted to.
ALTER TABLE employee.employee_master
  DROP COLUMN british_employee;
