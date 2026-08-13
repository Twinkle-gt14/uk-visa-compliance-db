-- 021_rtw_check_missing_columns.sql
--
-- Real gap, not an enhancement: the Right to Work step's form has
-- always captured Check Method, Document Evidence Type, Checked By
-- (name/role), Statutory Excuse Established, and Remarks - but
-- employee_rtw_check never had columns for any of them, so every
-- save silently dropped these fields. This is also why "Completed"
-- status was unreachable for RTW checks: the only field the backend
-- was checking (status) has no UI control that ever sets it -
-- statutory_excuse_established is the field that actually represents
-- whether a check succeeded.
ALTER TABLE employee.employee_rtw_check
  ADD COLUMN check_method TEXT,
  ADD COLUMN document_evidence_type TEXT,
  ADD COLUMN checked_by_name TEXT,
  ADD COLUMN checked_by_role TEXT,
  ADD COLUMN statutory_excuse_established TEXT,
  ADD COLUMN remarks TEXT;
