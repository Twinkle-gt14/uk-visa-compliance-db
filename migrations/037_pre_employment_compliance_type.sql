-- Settings > Compliance > Pre-employment Compliance: which compliance
-- check types appear on a candidate's Pre-hire Compliance checklist.
-- Same shape/pattern as reference.payslip_component, minus the
-- earning/deduction split (there's only one list here) - starts
-- genuinely empty per tenant, no default rows are seeded.
CREATE TABLE reference.pre_employment_compliance_type (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  slug TEXT NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  is_selected BOOLEAN NOT NULL DEFAULT true,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_pre_employment_compliance_type_tenant_slug UNIQUE (tenant_id, slug)
);
CREATE INDEX idx_pre_employment_compliance_type_tenant ON reference.pre_employment_compliance_type(tenant_id);
