-- =============================================================================
-- hl7_mapper.lua
-- Author: Conor Steward
-- Updated: 6/16/25
--
-- Purpose:
--   Maps parsed HL7 ORM^O01 messages into a normalized VDB structure with multiple tables.
--   Outputs structured data across eRequest, Patient, Physician, Organization, HL&Datum, and tissueCypherForm tables.
-- =============================================================================

local hl7_mapper = {}

-- Lookup tables
hl7_mapper.lookups = {
   PatientGender = { M = "Male", F = "Female", U = "-no value-" },
   ICDCode1 = {
      ["K22.70"] = "K22.70 Barrett's esophagus without dysplasia",
      ["K22.710"] = "K22.710 Barrett's esophagus with low grade dysplasia",
      ["K22.719"] = "K22.719 Barrett's esophagus with dysplasia, unspecified"
   }
}

-- Utility: Safe getter
local function get(v)
  return v and v.S and v:S() or nil
end

-- =============================================================================
-- MAPPING FUNCTIONS PER TABLE
-- =============================================================================

function hl7_mapper.mapERequest(ORM)
   local MSH, PID, PV1, IN1, GT1, DG1, ORC, OBR, OBX, NTE, ZEF = ORM.MSH, ORM.PID, ORM.PV1, ORM.IN1, ORM.GT1, ORM.DG1, ORM.ORC, ORM.OBR, ORM.OBX, ORM.NTE

   local T = {}

   T.ExternalOrgId             = get(MSH[4][1])
   T.ExternalEventId           = get(MSH[10])
   T.PrimaryPhysicianNPINumber = get(ORC[12][1][1])
   T.PrimaryPhysicianFirstName = get(ORC[12][1][3])
   T.PrimaryPhysicianLastName  = get(ORC[12][1][2])
   T.PrimaryPhysicianMiddleName = get(ORC[12][1][4])
   T.CollectionDate            = get(OBR[1][7])
   T.CollectorsComments        = get(OBR[1][39])
   T.AbnormalFlag              = get(OBX[4][5])
   T.Notes                     = get(OBX[6][5])

   return T
end

function hl7_mapper.mapPatient(PID)
   local T = {}
   T.PatientFirstName      = get(PID[5][1][2])
   T.PatientMiddleName     = get(PID[5][1][3])
   T.PatientLastName       = get(PID[5][1][1])
   T.PatientDOB            = get(PID[7])
   T.PatientGender         = hl7_mapper.lookups.PatientGender[get(PID[8])] or get(PID[8])
   T.PatientAddress1       = get(PID[11][1][1])
   T.PatientAddress2       = get(PID[11][1][2])
   T.PatientCity           = get(PID[11][1][3])
   T.PatientStateProvinceSelector = get(PID[11][1][4])
   T.PatientZipPostalCode  = get(PID[11][1][5])
   T.PatientPhone          = get(PID[13][1])
   T.AccountNumber         = get(PID[18][2])
   T.PatientSSN            = get(PID[19])
   return T
end

function hl7_mapper.mapPhysician(ORC, PV1)
   local T = {}
   T.TreatingClinicianNPINumber = get(PV1[7][1][1])
   T.TreatingClinicianLastName  = get(PV1[7][1][2])
   T.TreatingClinicianFirstName = get(PV1[7][1][3])
   T.PrimaryPhysicianNPINumber  = get(ORC[12][1][1])
   T.PrimaryPhysicianLastName   = get(ORC[12][1][2])
   T.PrimaryPhysicianFirstName  = get(ORC[12][1][3])
   T.PrimaryPhysicianMiddleName = get(ORC[12][1][4])
   T.PrimaryPhysicianSuffix     = get(ORC[12][1][5])
   return T
end

function hl7_mapper.mapOrganization(MSH)
   local T = {}
   T.SendingApp   = get(MSH[3][1])
   T.ExternalIntID   = get(MSH[4][1])
   return T
end

function hl7_mapper.mapHL7Datum(MSH, PID, PV1, IN1, GT1, DG1, ORC, OBR, OBX, NTE)
   local T = {}
   T.MSHSegment = get(MSH)
   T.PIDSegment = get(PID)
   T.PV1Segment = get(PV1)
   T.IN1Segment = get(IN1)
   T.GT1Segment = get(GT1)
   T.DG1Segment = get(DG1)
   T.ORCSegment = get(ORC)
   T.OBRSegment = get(OBR)
   T.OBXSegment = get(OBX)
   T.NTESegment = get(NTE)
   return T
end

-- =============================================================================
-- MAIN MAPPING FUNCTION
-- =============================================================================

function hl7_mapper.map(parsed)
   local T = {}
   T.eRequest           = { hl7_mapper.mapERequest(parsed) }
   T.Patient            = { hl7_mapper.mapPatient(parsed.PID) }
   T.Physician          = { hl7_mapper.mapPhysician(parsed.ORC, parsed.PV1) }
   T.Organization       = { hl7_mapper.mapOrganization(parsed.MSH) }
   T["HL7Datum"]        = { hl7_mapper.mapHL7Datum(parsed.MSH, parsed.PID, parsed.PV1, parsed.IN1, parsed.GT1, parsed.DG1, parsed.ORC, parsed.OBR, parsed.OBX, parsed.NTE)}
   return T
end

return hl7_mapper