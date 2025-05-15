--==================================================
-- hl7_parser.lua
-- Purpose: Parse and return the entire HL7 message structure.
--==================================================

local hl7_parser = {}

--==================================================
-- Parse the entire HL7 node tree into a Lua table
-- @param Msg (hl7.node): HL7 parsed node tree
-- @returns (hl7.node): Full parsed message object
--==================================================
function hl7_parser.parseOrder(Msg)
   -- No field-by-field mapping — just return the whole message for now
   return Msg
end

return hl7_parser