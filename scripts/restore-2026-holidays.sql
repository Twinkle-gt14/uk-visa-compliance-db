-- One-off DATA restoration for reference.holiday - not a schema
-- change, so this is NOT a numbered migration and should NOT be run
-- through db/scripts/migrate.js. Run it once, directly, against the
-- live DB (e.g. via psql through the Cloud SQL Auth Proxy).
--
-- Restores the same 8 England & Wales bank holidays for 2026 that
-- were seeded in the frontend's lib/settings-data.ts reference list.
-- tenant_id is looked up from reference.employer_profile (one row per
-- tenant) rather than hardcoded, so this runs as-is without editing.
--
-- Safe to re-run: ON CONFLICT DO NOTHING skips any date that's
-- already present (reference.holiday has a unique constraint on
-- (tenant_id, holiday_date) per the ConflictException in
-- api-service/src/settings/settings.service.ts).

INSERT INTO reference.holiday (tenant_id, holiday_date, name)
SELECT tenant_id, holiday_date, name
FROM (
  SELECT (SELECT tenant_id FROM reference.employer_profile LIMIT 1) AS tenant_id, v.holiday_date, v.name
  FROM (VALUES
    ('2026-01-01'::date, 'New Year''s Day'),
    ('2026-04-03'::date, 'Good Friday'),
    ('2026-04-06'::date, 'Easter Monday'),
    ('2026-05-04'::date, 'Early May Bank Holiday'),
    ('2026-05-25'::date, 'Spring Bank Holiday'),
    ('2026-08-31'::date, 'Summer Bank Holiday'),
    ('2026-12-25'::date, 'Christmas Day'),
    ('2026-12-28'::date, 'Boxing Day (substitute day)')
  ) AS v(holiday_date, name)
) AS rows_to_insert
WHERE tenant_id IS NOT NULL
ON CONFLICT (tenant_id, holiday_date) DO NOTHING;
