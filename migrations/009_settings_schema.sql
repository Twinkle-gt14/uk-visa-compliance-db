-- Settings / reference-data schema for the screens that had no
-- backend at all before this: Position, Visa Type, Work Location,
-- Holidays, and a new Employer (company/sponsor) profile screen.
-- Department already exists (migration 001) but only ever got rows
-- via Employee's auto-create-on-save - this migration doesn't touch
-- its table, only adds real CRUD for it in the service layer.

-- ---------------------------------------------------------------------
-- Simple named reference lists: position, visa_type, work_location.
-- Same shape as reference.department - tenant-scoped, unique name per
-- tenant, no fixed enum of values since these are genuinely
-- employer-configurable lists.
-- ---------------------------------------------------------------------
CREATE TABLE reference.position (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  name TEXT NOT NULL,
  CONSTRAINT uq_position_tenant_name UNIQUE (tenant_id, name)
);
CREATE INDEX idx_position_tenant ON reference.position(tenant_id);

CREATE TABLE reference.visa_type (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  name TEXT NOT NULL,
  CONSTRAINT uq_visa_type_tenant_name UNIQUE (tenant_id, name)
);
CREATE INDEX idx_visa_type_tenant ON reference.visa_type(tenant_id);

CREATE TABLE reference.work_location (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  name TEXT NOT NULL,
  CONSTRAINT uq_work_location_tenant_name UNIQUE (tenant_id, name)
);
CREATE INDEX idx_work_location_tenant ON reference.work_location(tenant_id);

-- ---------------------------------------------------------------------
-- reference.holiday - the bank holiday calendar. This closes a real
-- open point flagged back in the Attendance module: "Bank Holiday"
-- has been a display category with no actual data source behind it -
-- the frontend's lib/holidays.ts is a hardcoded list. This table is
-- the real, tenant-scoped source of truth going forward.
-- ---------------------------------------------------------------------
CREATE TABLE reference.holiday (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  holiday_date DATE NOT NULL,
  name TEXT NOT NULL,
  CONSTRAINT uq_holiday_tenant_date UNIQUE (tenant_id, holiday_date)
);
CREATE INDEX idx_holiday_tenant ON reference.holiday(tenant_id);

-- ---------------------------------------------------------------------
-- reference.employer_profile - one row per tenant (the new "Employer"
-- Settings screen: company/sponsor details for a UK visa compliance
-- context). Upserted as a singleton rather than a list.
-- ---------------------------------------------------------------------
CREATE TABLE reference.employer_profile (
  tenant_id UUID PRIMARY KEY,
  company_name TEXT,
  trading_name TEXT,
  registered_address TEXT,
  companies_house_number TEXT,
  sponsor_licence_number TEXT,
  paye_reference TEXT,
  accounts_office_reference TEXT,
  primary_contact_name TEXT,
  primary_contact_email TEXT,
  primary_contact_phone TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- RLS - same tenant-isolation pattern as every other reference table.
-- ---------------------------------------------------------------------
ALTER TABLE reference.position ENABLE ROW LEVEL SECURITY;
CREATE POLICY position_tenant_isolation ON reference.position
  USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);

ALTER TABLE reference.visa_type ENABLE ROW LEVEL SECURITY;
CREATE POLICY visa_type_tenant_isolation ON reference.visa_type
  USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);

ALTER TABLE reference.work_location ENABLE ROW LEVEL SECURITY;
CREATE POLICY work_location_tenant_isolation ON reference.work_location
  USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);

ALTER TABLE reference.holiday ENABLE ROW LEVEL SECURITY;
CREATE POLICY holiday_tenant_isolation ON reference.holiday
  USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);

ALTER TABLE reference.employer_profile ENABLE ROW LEVEL SECURITY;
CREATE POLICY employer_profile_tenant_isolation ON reference.employer_profile
  USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);

-- app_service needs full CRUD (including DELETE, unlike the blanket
-- schema-wide grant in migration 002 which stops at UPDATE) on all of
-- these - deleting a position/visa-type/work-location/holiday entry is
-- a legitimate Settings action. reference.department is included here
-- too - it already existed (migration 001) but only ever got rows via
-- Employee's auto-create-on-save; this is what makes real Department
-- CRUD in Settings possible for the first time.
GRANT SELECT, INSERT, UPDATE, DELETE ON reference.department TO app_service;
GRANT SELECT, INSERT, UPDATE, DELETE ON reference.position TO app_service;
GRANT SELECT, INSERT, UPDATE, DELETE ON reference.visa_type TO app_service;
GRANT SELECT, INSERT, UPDATE, DELETE ON reference.work_location TO app_service;
GRANT SELECT, INSERT, UPDATE, DELETE ON reference.holiday TO app_service;
GRANT SELECT, INSERT, UPDATE, DELETE ON reference.employer_profile TO app_service;
