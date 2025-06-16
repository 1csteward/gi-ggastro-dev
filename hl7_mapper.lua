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
   local MSH, ORC, OBR, OBX = ORM.MSH, ORM.ORC, ORM.OBR, ORM.OBX
   local T = {}

   T.ExternalOrgId         = get(MSH[4][1])
   T.ExternalEventId       = get(MSH[10])
   T.OrderControl          = get(ORC[1])
   T.OrderPlacerNumber     = get(ORC[2][1])
   T.OrderingProviderFirst = get(ORC[12][3])
   T.OrderingProviderLast  = get(ORC[12][2])
   T.OrderTimestamp        = get(ORC[9][1])
   T.TestCode              = get(OBR[4][1])
   T.TestDescription       = get(OBR[4][2])
   T.CollectionDate        = get(OBR[7][1])
   T.SpecimenSource        = get(OBR[15][1])
   T.CollectorsComments    = get(OBR[13][1])
   T.ObservationValue      = get(OBX[5][1])
   T.Units                 = get(OBX[6][1])
   T.AbnormalFlag          = get(OBX[8])
   T.Notes                 = get(OBX[3][2])

   return T
end

function hl7_mapper.mapPatient(PID)
   local T = {}
   T.PatientFirstName      = get(PID[5][2])
   T.PatientMiddleName     = get(PID[5][3])
   T.PatientLastName       = get(PID[5][1][1])
   T.PatientDOB            = get(PID[7])
   T.PatientGender         = hl7_mapper.lookups.PatientGender[get(PID[8])] or get(PID[8])
   T.PatientAddress1       = get(PID[11][1])
   T.PatientAddress2       = get(PID[11][2])
   T.PatientCity           = get(PID[11][3])
   T.PatientStateProvinceSelector = get(PID[11][4])
   T.PatientZipPostalCode  = get(PID[11][5])
   T.PatientPhone          = get(PID[13][1])
   T.AccountNumber         = get(PID[18][1])
   T.PatientSSN            = get(PID[19])
   return T
end

function hl7_mapper.mapPhysician(ORC, OBR)
   local T = {}
   T.TreatingClinicianNPINumber = get(ORC[12][1])
   T.TreatingClinicianLastName  = get(ORC[12][2])
   T.TreatingClinicianFirstName = get(ORC[12][3])
   T.PrimaryPhysicianNPINumber  = get(OBR[16][1])
   T.PrimaryPhysicianLastName   = get(OBR[16][2])
   T.PrimaryPhysicianFirstName  = get(OBR[16][3])
   T.PrimaryPhysicianMiddleName = get(OBR[16][4])
   T.PrimaryPhysicianSuffix     = get(OBR[16][5])
   return T
end

function hl7_mapper.mapOrganization(MSH)
   local T = {}
   T.SendingApp   = get(MSH[3][1])
   T.SendingFac   = get(MSH[4][1])
   T.ReceivingApp = get(MSH[5][1])
   T.ReceivingFac = get(MSH[6][1])
   return T
end

function hl7_mapper.mapHLDatum(OBX)
   local T = {}
   T.ObservationValue = get(OBX[5][1])
   T.Units            = get(OBX[6][1])
   T.AbnormalFlag     = get(OBX[8])
   T.ObservationNotes = get(OBX[3][2])
   return T
end

function hl7_mapper.mapTissueForm(NTE)
   local T = {}
   T.Notes = get(NTE[3])
   return T
end

-- =============================================================================
-- MAIN MAPPING FUNCTION
-- =============================================================================

function hl7_mapper.map(parsed)
   local T = {}
   T.eRequest           = { hl7_mapper.mapERequest(parsed) }
   T.Patient            = { hl7_mapper.mapPatient(parsed.PID) }
   T.Physician          = { hl7_mapper.mapPhysician(parsed.ORC, parsed.OBR) }
   T.Organization       = { hl7_mapper.mapOrganization(parsed.MSH) }
   T["HL&Datum"]        = { hl7_mapper.mapHLDatum(parsed.OBX) }
   T.tissueCypherForm   = { hl7_mapper.mapTissueForm(parsed.NTE or {}) }
   return T
end

return hl7_mapper