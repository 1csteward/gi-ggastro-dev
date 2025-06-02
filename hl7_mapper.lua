-- ====================================================================
-- hl7_mapper.lua
-- Author: Conor Steward
-- Date Created: 5/29/25
-- Last Edit: 6/2/25
--
-- Purpose:
-- Maps the parsed HL7 fields/subfields to LIMS tables and fields.
-- Lookups for LIMS tables.
-- Provides helpers for consistent mapping and transformation.
--
-- Notes:
-- Called by main. Relies on a parsed HL7 message structure.
-- ====================================================================

local hl7_mapper ={}
local accessor = require 'hl7_accessor' -- Unified HL7 path reader

-- Direct Mappings: LIMS Field -> HL7 segment.field.component
hl7_mapper.fieldMap = {
	ExternalOrgId = "MSH.4", -- Sending Facility
   ExternalEventId = "MSH.10", -- Message Control ID
   
   PatientFirstName = "PID.5.2", -- Patient First Name
   PatientMiddleName = "PID.5.3", -- Patient Middle Name
   PatientLastName = "PID.5.1", -- Patient Last Name
   PatientDOB = "PID.7", -- Patient DOB: YYYYMMDD
   PatientGender = "PID.8", -- Patient Gender: "Male" "Female" "-no value-"
   PatientAddress1 = "PID.11.1", -- Patient Address
   PatientAddress2 = "PID.11.2", -- Address cont.
   PatientCity = "PID.11.3", -- Patient City
   PatientStateProvinceSelector = "PID.11.4", -- Patient State: Two letter designation i.e AZ, AK, TX, etc.
   PatientZipPostalCode = "PID.11.5", -- Patient Zip Code
   PatientPhone = "PID.13.1", -- Patient Phone: xxxxxxxxx
   AccountNumber = "PID.18", -- Patient Account Number
   PatientSSN = "PID.19", -- Patient SSN: xxxxxxxxx
   
   TreatingClinicianNPINumber = "PV1.7.1", -- Treating ClinicianNPINumber: May not be mappable, if not must be inserted into treating clinician table
   TreatingClinicianLastName = "PV1.7.2", -- Treating Clinician Last Name
   TreatingClinicianFirstName = "PV1.7.3", -- Treating CLinician First Name
   
   PrimaryPhysicianNPINumber = "PV1.8.1", -- Primary Physisian NPI Number
   PrimaryPhysicianLastName = "PV1.8.2", -- Primary Physisican Last Name
   PrimaryPhysicianFirstName = "PV1.8.3", -- Primary Physician First Name
   PrimaryPhysicianMiddleName = "PV1.8.4", -- Primary HPysician Middle Name
   PrimaryPhysicianSuffix = "PV1.8.5", -- Primary Physician Suffix
   
   InsuranceName = "IN1.4.1", -- Insruance Company Name
   InsurancePhone = "IN1.7.1", -- Insurance Phone Number
   InsurancePolicyNumber = "IN1.36", -- Insurance Policy Number
   
   ICDCode1 = "DG1.3", -- IDC10 Code: Only 3 options avalible
   
   CollectionDate = "OBR.7", -- Specimen Collection Date
   Comments = "OBR.39" -- Specimen collectors Comments
}

-- Lookups for LIMS-Table compatability
hl7_mapper.lookups = {
   PatientGender = {
   M = "Male",
   F = "Female",
   U = "-no value-"
   },
   
   ICDCode1 = {
   ["K22.70"] = "K22.70 Barrett's esophagus without dysplasia",
   ["K22.710"] = "K22.710 Barrett's esophagus with low grade dysplasia",
   ["K22.719"] = "K22.719 Barrett's esophagus with dysplasia, unspecified"
   }
}

-- Function: getHL7Value
-- Purpose: Retrieve a value from the parsed HL7 table using a path from fieldMap.
-- Input:
--   hl7 (table) - Parsed HL7 message
--   field (string) - Logical LIMS field name
-- Output:
--   string or nil - HL7 value at mapped location
function hl7_mapper.getHL7Value(hl7, field)
   local path = hl7_mapper.fieldMap[field]
   if not path then
      iguana.logWarning(string.format("No mapping path defined for field: %s", field))
      return nil
   end
   local value = accessor.get(hl7, path)
   if not value then
      iguana.logWarning(string.format("Value not found at path %s for field %s", path, field))
   end
   return value
end

-- Function: lookup
-- Purpose: Translate HL7 field values to LIMS-compatible values using predefined tables.
-- Input:
--   field (string) - LIMS field name for which lookup may exist
--   value (string) - HL7 value to translate
-- Output:
--   string - Translated value if mapping exists; original value otherwise
function hl7_mapper.lookup(field, value)
   local map = hl7_mapper.lookups[field]
   if map then
      if not map[value] then
         iguana.logWarning(string.format("No lookup match for field %s value %s", field, value or "nil"))
      end
      return map[value] or value
   end
   return value
end

-- Function: map
-- Purpose: Convert parsed HL7 fields into a flat table suitable for LIMS API submission.
-- Input:
--   parsedHL7 (table) - Parsed HL7 tree
-- Output:
--   table - Key/value pairs matching LIMS schema
function hl7_mapper.map(parsedHL7)
   local output = {}
   for fieldName, _ in pairs(hl7_mapper.fieldMap) do
      local rawVal = hl7_mapper.getHL7Value(parsedHL7, fieldName)
      local mappedVal = hl7_mapper.lookup(fieldName, rawVal)
      output[fieldName] = mappedVal
   end
   return output
end

return hl7_mapper