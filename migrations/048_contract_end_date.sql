-- Employee Register's Work Details step: contract end date, computed
-- from Actual Joining date (date_of_joining) + "Contract duration - in
-- months". Computed and set by the front-end (WorkStep.tsx) whenever
-- either input changes, same "system-determined, not independently
-- editable" pattern as cos_type - stored here (rather than only ever
-- computed on read) so Employee Contract End and any other consumer
-- can query it directly instead of re-deriving it every time.
ALTER TABLE employee.employee_master
  ADD COLUMN contract_end_date DATE;
