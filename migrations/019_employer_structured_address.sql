-- 019_employer_structured_address.sql
--
-- Registered Address moves from one free-text field to individual
-- fields (Settings > Employer redesign). The old registered_address
-- column is left in place rather than dropped - non-destructive, and
-- avoids losing whatever was typed into it previously even though the
-- UI no longer reads/writes it.
ALTER TABLE reference.employer_profile
  ADD COLUMN address_line1 TEXT,
  ADD COLUMN address_line2 TEXT,
  ADD COLUMN city TEXT,
  ADD COLUMN county TEXT,
  ADD COLUMN postcode TEXT,
  ADD COLUMN country TEXT;
