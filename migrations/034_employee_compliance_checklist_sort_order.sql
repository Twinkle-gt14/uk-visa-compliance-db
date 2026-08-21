-- The previous ORDER BY category, id sorted by a random UUID within
-- each category, scrambling section groupings entirely instead of
-- preserving the workbook's own row order. sort_order captures each
-- row's position as parsed from the file, so display order can
-- actually match the source spreadsheet.
ALTER TABLE reference.employee_compliance_checklist
  ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0;
