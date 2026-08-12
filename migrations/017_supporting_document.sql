-- compliance.supporting_document - metadata for Supporting Evidence
-- files uploaded against a candidate's Pre-Employment Compliance
-- Check. File bytes never pass through this app's own database or
-- API server - only this metadata row does. The actual bytes live in
-- Google Cloud Storage, uploaded/downloaded via short-lived signed
-- URLs (see UKVisaCompliance_FSD_Document_Upload_Storage.docx for the
-- full design). Deletion is soft-delete only (deleted_at) - documents
-- are compliance evidence and must never be hard-deleted.
CREATE TABLE compliance.supporting_document (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  employee_id UUID NOT NULL REFERENCES employee.employee_master(id),
  document_type TEXT NOT NULL, -- CV, Job Description, Offer Letter, Qualification Evidence, Right to Work Evidence, Other
  description TEXT,
  original_filename TEXT NOT NULL,
  storage_key TEXT NOT NULL,
  content_type TEXT NOT NULL,
  size_bytes BIGINT NOT NULL,
  checksum_md5 TEXT, -- from GCS object metadata on upload confirmation, not computed server-side
  status TEXT NOT NULL DEFAULT 'Pending', -- Pending | Uploaded | Failed | Deleted
  uploaded_by TEXT,
  uploaded_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);
CREATE INDEX idx_supporting_document_tenant ON compliance.supporting_document(tenant_id);
CREATE INDEX idx_supporting_document_employee ON compliance.supporting_document(employee_id);
CREATE INDEX idx_supporting_document_status ON compliance.supporting_document(status);

ALTER TABLE compliance.supporting_document ENABLE ROW LEVEL SECURITY;
CREATE POLICY supporting_document_tenant_isolation ON compliance.supporting_document
  USING (tenant_id = current_setting('app.current_tenant_id', true)::uuid);

-- No DELETE grant - enforces soft-delete only at the DB privilege
-- level, not just application convention.
GRANT SELECT, INSERT, UPDATE ON compliance.supporting_document TO app_service;
