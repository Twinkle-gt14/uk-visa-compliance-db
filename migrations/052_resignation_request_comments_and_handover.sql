-- Adds the "Additional Comments" and "Handover Plan" fields to the
-- resignation submission form (see app/resignation/page.tsx), on top
-- of the existing free-text "reason" column from 041. Both optional,
-- same as reason.
ALTER TABLE employee.resignation_request
  ADD COLUMN additional_comments TEXT,
  ADD COLUMN handover_plan TEXT;
