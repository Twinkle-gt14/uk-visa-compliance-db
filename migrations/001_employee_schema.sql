-- Employee Record Management schema.
-- Run once, in order, via: gcloud sql connect uk-visa-compliance-db --user=postgres --database=uk_visa_compliance
-- then paste this whole file at the psql prompt.
-- Per Technical Design Document - Employee Record Management (API & Data Layer), Section 3.

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE SCHEMA IF NOT EXISTS employee;

-- Minimal reference.department so employee_master's FK has something to
-- point at. If reference.department already exists from Settings work,
-- this is a no-op.
CREATE SCHEMA IF NOT EXISTS reference;
CREATE TABLE IF NOT EXISTS reference.department (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  name TEXT NOT NULL,
  CONSTRAINT uq_department_tenant_name UNIQUE (tenant_id, name)
);

-- 3.1 employee.employee_master
CREATE TABLE employee.employee_master (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  employee_reference_no TEXT NOT NULL,
  first_name TEXT NOT NULL,
  middle_name TEXT,
  last_name TEXT NOT NULL,
  date_of_birth DATE NOT NULL,
  gender TEXT,
  marital_status TEXT,
  nationality TEXT,
  ni_number_encrypted BYTEA,
  -- Deterministic HMAC of the NI number, used only for the uniqueness
  -- check below. pgp_sym_encrypt() is intentionally non-deterministic
  -- (random IV each call), so two identical NI numbers produce
  -- different ciphertext and a UNIQUE constraint on ni_number_encrypted
  -- would never actually catch a duplicate - this column is what makes
  -- FSD Section 6.3's duplicate check actually work.
  ni_number_hash TEXT,
  job_title TEXT NOT NULL,
  department_id UUID NOT NULL REFERENCES reference.department(id),
  employment_type TEXT,
  work_location TEXT,
  work_timing TEXT,
  standard_hours_per_week NUMERIC(5, 2),
  soc_number TEXT,
  reporting_manager_id UUID REFERENCES employee.employee_master(id),
  project_work_branch TEXT,
  sponsored_employee BOOLEAN,
  british_employee BOOLEAN,
  employee_id_label TEXT, -- the free-text "Employee ID" field the wizard captures (distinct from the UUID primary key)
  job_contract_file_reference TEXT,
  date_of_joining DATE NOT NULL,
  record_status TEXT NOT NULL DEFAULT 'Active',
  is_deleted BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_employee_tenant_reference UNIQUE (tenant_id, employee_reference_no),
  CONSTRAINT uq_employee_tenant_ni UNIQUE (tenant_id, ni_number_hash),
  CONSTRAINT ck_employee_status CHECK (record_status IN ('Active', 'Inactive', 'Exited'))
);
CREATE INDEX idx_employee_tenant_id ON employee.employee_master(tenant_id);
CREATE INDEX idx_employee_department ON employee.employee_master(department_id);

-- 3.2 employee.employee_contact_detail
CREATE TABLE employee.employee_contact_detail (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  employee_id UUID NOT NULL REFERENCES employee.employee_master(id),
  contact_type TEXT NOT NULL, -- 'email' | 'phone' | 'address'
  contact_subtype TEXT,
  value TEXT,
  line1 TEXT,
  line2 TEXT,
  city TEXT,
  county TEXT,
  postcode TEXT,
  country TEXT,
  is_primary BOOLEAN NOT NULL DEFAULT false,
  is_removed BOOLEAN NOT NULL DEFAULT false,
  CONSTRAINT ck_contact_type CHECK (contact_type IN ('email', 'phone', 'address'))
);
CREATE UNIQUE INDEX uq_contact_primary_per_type ON employee.employee_contact_detail(employee_id, contact_type)
  WHERE is_primary AND NOT is_removed;
CREATE INDEX idx_contact_detail_employee ON employee.employee_contact_detail(employee_id);

-- 3.3 employee.employee_emergency_contact
CREATE TABLE employee.employee_emergency_contact (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  employee_id UUID NOT NULL REFERENCES employee.employee_master(id),
  full_name TEXT NOT NULL,
  relationship TEXT NOT NULL,
  primary_phone TEXT NOT NULL,
  secondary_phone TEXT,
  address TEXT
);
CREATE INDEX idx_emergency_contact_employee ON employee.employee_emergency_contact(employee_id);

-- 3.4 employee.employee_bank_detail
CREATE TABLE employee.employee_bank_detail (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  employee_id UUID NOT NULL REFERENCES employee.employee_master(id),
  account_holder_name TEXT,
  bank_name TEXT,
  account_number_encrypted BYTEA,
  sort_code_encrypted BYTEA,
  iban_encrypted BYTEA,
  document_file_reference TEXT,
  CONSTRAINT uq_bank_employee UNIQUE (employee_id)
);

-- 3.5 employee.employee_qualification & employee_certification
CREATE TABLE employee.employee_qualification (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  employee_id UUID NOT NULL REFERENCES employee.employee_master(id),
  institution TEXT,
  qualification TEXT,
  field_of_study TEXT,
  start_date DATE,
  end_date DATE,
  grade TEXT,
  certificate_file_reference TEXT
);
CREATE INDEX idx_qualification_employee ON employee.employee_qualification(employee_id);

CREATE TABLE employee.employee_certification (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  employee_id UUID NOT NULL REFERENCES employee.employee_master(id),
  name TEXT,
  issuing_body TEXT,
  certificate_number TEXT,
  issue_date DATE,
  expiry_date DATE,
  file_reference TEXT
);
CREATE INDEX idx_certification_employee ON employee.employee_certification(employee_id);

-- 3.6 Immigration tables (split from a single-row design - see Technical Design Section 2)
CREATE TABLE employee.employee_passport_detail (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  employee_id UUID NOT NULL REFERENCES employee.employee_master(id),
  passport_number TEXT,
  issuing_country TEXT,
  issue_date DATE,
  expiry_date DATE,
  file_reference TEXT,
  CONSTRAINT uq_passport_employee UNIQUE (employee_id)
);

CREATE TABLE employee.employee_visa_detail (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  employee_id UUID NOT NULL REFERENCES employee.employee_master(id),
  visa_type TEXT,
  visa_number TEXT,
  issue_date DATE,
  expiry_date DATE,
  conditions TEXT,
  file_reference TEXT,
  CONSTRAINT uq_visa_employee UNIQUE (employee_id)
);
CREATE INDEX idx_visa_expiry ON employee.employee_visa_detail(expiry_date);

CREATE TABLE employee.employee_cos_detail (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  employee_id UUID NOT NULL REFERENCES employee.employee_master(id),
  licence_number TEXT,
  sponsor_name TEXT,
  certificate_number TEXT,
  certificate_date DATE,
  assigned_date DATE,
  expiry_date DATE,
  sponsor_note TEXT,
  file_reference TEXT,
  CONSTRAINT uq_cos_employee UNIQUE (employee_id)
);

CREATE TABLE employee.employee_rtw_check (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  employee_id UUID NOT NULL REFERENCES employee.employee_master(id),
  share_code TEXT,
  rtw_reference TEXT,
  date_of_check DATE,
  status TEXT,
  expiry_date DATE,
  attachment_file_reference TEXT,
  CONSTRAINT ck_rtw_status CHECK (status IS NULL OR status IN ('Approved', 'Pending', 'Rejected'))
);
CREATE INDEX idx_rtw_check_employee ON employee.employee_rtw_check(employee_id);

-- 3.7 employee.employee_document
CREATE TABLE employee.employee_document (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  employee_id UUID NOT NULL REFERENCES employee.employee_master(id),
  file_reference TEXT NOT NULL,
  document_type TEXT,
  description TEXT,
  expiry_date DATE
);
CREATE INDEX idx_document_employee ON employee.employee_document(employee_id);

-- 3.8 Row-Level Security - one ALTER/CREATE POLICY pair per table above.
ALTER TABLE employee.employee_master ENABLE ROW LEVEL SECURITY;
CREATE POLICY employee_master_tenant_isolation ON employee.employee_master
  USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);

ALTER TABLE employee.employee_contact_detail ENABLE ROW LEVEL SECURITY;
CREATE POLICY employee_contact_detail_tenant_isolation ON employee.employee_contact_detail
  USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);

ALTER TABLE employee.employee_emergency_contact ENABLE ROW LEVEL SECURITY;
CREATE POLICY employee_emergency_contact_tenant_isolation ON employee.employee_emergency_contact
  USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);

ALTER TABLE employee.employee_bank_detail ENABLE ROW LEVEL SECURITY;
CREATE POLICY employee_bank_detail_tenant_isolation ON employee.employee_bank_detail
  USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);

ALTER TABLE employee.employee_qualification ENABLE ROW LEVEL SECURITY;
CREATE POLICY employee_qualification_tenant_isolation ON employee.employee_qualification
  USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);

ALTER TABLE employee.employee_certification ENABLE ROW LEVEL SECURITY;
CREATE POLICY employee_certification_tenant_isolation ON employee.employee_certification
  USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);

ALTER TABLE employee.employee_passport_detail ENABLE ROW LEVEL SECURITY;
CREATE POLICY employee_passport_detail_tenant_isolation ON employee.employee_passport_detail
  USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);

ALTER TABLE employee.employee_visa_detail ENABLE ROW LEVEL SECURITY;
CREATE POLICY employee_visa_detail_tenant_isolation ON employee.employee_visa_detail
  USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);

ALTER TABLE employee.employee_cos_detail ENABLE ROW LEVEL SECURITY;
CREATE POLICY employee_cos_detail_tenant_isolation ON employee.employee_cos_detail
  USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);

ALTER TABLE employee.employee_rtw_check ENABLE ROW LEVEL SECURITY;
CREATE POLICY employee_rtw_check_tenant_isolation ON employee.employee_rtw_check
  USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);

ALTER TABLE employee.employee_document ENABLE ROW LEVEL SECURITY;
CREATE POLICY employee_document_tenant_isolation ON employee.employee_document
  USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);

-- NOTE: the API currently connects to Postgres as DB_USER=postgres (a
-- superuser), which bypasses RLS by default regardless of the policies
-- above. These policies have no effect until the API's connection is
-- switched to a real, non-superuser app_service role - see db.ts's
-- withTenant() doc comment and Technical Design Document Section 4.2.
