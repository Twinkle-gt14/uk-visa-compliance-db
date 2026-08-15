-- Right to Work UI/logic rework (mockup step 13 "Right to work check").
-- Real gaps against the spec, not enhancements: document_evidence_type
-- has only ever held "List A" / "List B", with no way to distinguish
-- Group 1 (excuse runs to the document's own expiry) from Group 2
-- (excuse is a fixed 6 months from a Positive Verification Notice,
-- recurring) - two rules with genuinely different follow-up
-- calculations that were previously conflated. Branch-specific fields
-- for the Online and IDSP check methods didn't exist at all.

ALTER TABLE employee.employee_rtw_check
  -- Manual branch
  ADD COLUMN document_type TEXT,
  ADD COLUMN document_expiry_date DATE,       -- List B Group 1 only
  ADD COLUMN pvn_date DATE,                   -- List B Group 2 only
  -- Online branch
  ADD COLUMN online_code_issued_date DATE,
  ADD COLUMN online_permission_limit TEXT,    -- 'No time limit shown' | 'Time-limited'
  ADD COLUMN online_expiry_date DATE,         -- only when online_permission_limit = 'Time-limited'
  -- IDSP branch
  ADD COLUMN idsp_provider TEXT,
  -- Common to all three branches
  ADD COLUMN photo_match_confirmed BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN known_reasonable_cause_flag BOOLEAN NOT NULL DEFAULT false;

-- Engagement type (Direct employee / LLP partner / Directly-engaged
-- contractor / Zero-hours worker) is a property of the working
-- relationship itself, not of any one check - it doesn't change from
-- check to check, so it lives on employee_master rather than being
-- repeated on every employee_rtw_check row.
ALTER TABLE employee.employee_master ADD COLUMN rtw_engagement_type TEXT;
