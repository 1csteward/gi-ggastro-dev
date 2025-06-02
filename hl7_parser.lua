-- ====================================================
-- hl7_parser.lua
-- Author: Conor Steward
-- Date Created: 5/30/25
-- Last Edit: 6/2/25
--
-- Purpose:
-- Ingests raw HL7 messages and returns a parsed HL7 tree.
-- Parses using Interfaceware's native hl7.parse module.
--
-- Notes:
-- - Assumes HL7 message is a valid string.
-- - Logs error and returns nil if parsing fails.
-- ====================================================

local hl7 = require 'hl7'

local hl7_parser = {}
   
-- Function: parse
-- Purpose: Safely parse a raw HL7 string into a Lua-accessible HL7 tree.
-- Params:
--   rawHl7 (string) - Raw HL7 message as string input
-- Returns:
--   table or nil - Parsed HL7 tree if successful; nil if parsing fails
function hl7_parser.parse(rawHl7)
   local success, parsed = pcall(function()
         return hl7.parse{v= rawHl7}
      end)
   
   if not success then
      lguana.logError("Failed to parse HL7 message. Input may be malformed.")
      return nil
   end
   
   return parsed
end

return hl7_parser