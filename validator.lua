--==================================================
-- validator.lua
-- Purpose: Validate required segments and fields in HL7 messages.
--==================================================

local validator = {}

-- Define required HL7 fields
local requiredFields = {
   {Segment='MSH', FieldPath='MSH.1'},
   {Segment='MSH', FieldPath='MSH.2'},
   {Segment='MSH', FieldPath='MSH.3'},
   {Segment='MSH', FieldPath='MSH.4'},
   {Segment='MSH', FieldPath='MSH.6'},
   {Segment='MSH', FieldPath='MSH.7'},
   {Segment='MSH', FieldPath='MSH.9'},
   {Segment='MSH', FieldPath='MSH.10'},
   {Segment='MSH', FieldPath='MSH.11'},
   {Segment='MSH', FieldPath='MSH.12'},
   {Segment='PID', FieldPath='PID.1'},
   {Segment='PID', FieldPath='PID.3'},
   {Segment='PID', FieldPath='PID.5'},
   {Segment='PID', FieldPath='PID.7'},
   {Segment='IN1', FieldPath='IN1.1'},
   {Segment='IN1', FieldPath='IN1.47'},
   {Segment='NTE', FieldPath='NTE.1'},
   {Segment='NTE', FieldPath='NTE.2'},
   {Segment='DG1', FieldPath='DG1.1'},
   {Segment='DG1', FieldPath='DG1.3'},
   {Segment='ORC', FieldPath='ORC.2'},
   {Segment='ORC', FieldPath='ORC.4'},
   {Segment='ORC', FieldPath='ORC.9'},
   {Segment='OBR', FieldPath='OBR.1'},
   {Segment='OBR', FieldPath='OBR.4'},
   {Segment='OBR', FieldPath='OBR.6'},
   {Segment='OBX', FieldPath='OBX.1'}
}

--==================================================
-- Validate an HL7 message structure
-- @param msg (hl7.node): HL7 message node
-- @returns (table): List of error messages if missing fields
--==================================================
function validator.validate(msg)
   local errors = {}

   for _, req in ipairs(requiredFields) do
      local val = msg:find(req.FieldPath)[1]
      if not val or val:isNull() then
         table.insert(errors, string.format('Missing required %s field: %s', req.Segment, req.FieldPath))
      end
   end
   
   return errors
end

return validator