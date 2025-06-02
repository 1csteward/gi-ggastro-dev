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

-- Function: extractHL7Value
-- Purpose: Extracts a string value from a parsed HL7 tree based on a segment.field[.component] path.
-- Input:
--   hl7 (table) - Parsed HL7 structure
--   path (string) - HL7 path to field (e.g., "PID.5.2")
-- Output:
--   string or nil - Extracted field value, if present
local function extractHL7Value(hl7, path)
   local seg, field, comp = path:match("^(%u+).(%d+)%.?(%d*)$")
   local segNode = hl7[seg] and hl7[seg][1]  -- Always use first repetition
   if not segNode then return nil end

   local val = segNode[tonumber(field)]
   if comp ~= "" then val = val and val[tonumber(comp)] end
   return val and val:S() or nil
end

-- Function: basicValidate
-- Purpose: Check presence of required fields in a parsed HL7 message.
-- Input:
--   hl7 (table) - Parsed HL7 structure
-- Output:
--   table - List of strings describing missing fields
function validator.basicValidate(hl7)
   local errors = {}

   for _, path in ipairs(requiredPaths) do
      local value = extractHL7Value(hl7, path)
      if not value or value == "" then
         table.insert(errors, "Missing required field: " .. path)
         iguana.logWarning("Missing required HL7 field: " .. path)
      end
   end

   return errors
end

return validator