-- ====================================================================
-- validator.lua
-- Author: Conor Steward
-- Date Created: 5/25/25
-- Last Edit: 6/2/25
--
-- Purpose:
-- Validate presence of required fields and components in parsed HL7.
-- Returns list of missing field paths for external error handling/logging.
--
-- Notes:
-- - This is a shallow validator (presence only, no semantic checks).
-- - Intended to be called by main before mapping or API transmission.
-- ====================================================================

local validator = {}
local accessor = require 'hl7_accessor'

-- Required HL7 segment.field[.component] paths
-- Can be extended to support interface-specific validations
local requiredPaths = {
   "MSH.1", "MSH.2", "MSH.3", "MSH.4", "MSH.7", "MSH.9", "MSH.10", "MSH.11", "MSH.12",
   "PID.1", "PID.3", "PID.4", "PID.5", "PID.7",
   "PV1.1", "PV1.7",
   "IN1.1", "IN1.4",
   "DG1.1", "DG1.3",
   "ORC.1", "ORC.2", "ORC.9", "ORC.12",
   "OBR.1", "OBR.2", "OBR.7",
   "OBX.1", "OBX.2",
   "NTE.1", "NTE.2"
}

-- Function: basicValidate
-- Purpose: Check presence of required fields in a parsed HL7 message.
-- Input:
--   hl7 (table) - Parsed HL7 structure
-- Output:
--   table - List of strings describing missing fields
function validator.basicValidate(hl7)
   local errors = {}

   for _, path in ipairs(requiredPaths) do
      local value = accessor.get(hl7, path)
      if not value or value == "" then
         table.insert(errors, "Missing required field: " .. path)
         iguana.logWarning("Missing required HL7 field: " .. path)
      end
   end

   return errors
end

return validator