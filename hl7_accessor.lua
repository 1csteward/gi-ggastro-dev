-- ====================================================================
-- hl7_accessor.lua
-- Author: Conor Steward
-- Date Created: 6/2/25
--
-- Purpose:
-- Access deeply nested HL7 fields using a dot-separated path:
--   format: SEGMENT[.field][.repetition][.component][.subcomponent]
--
-- Usage:
--   local accessor = require 'hl7_accessor'
--   local value = accessor.get(msg, "PID.5.2.1") as example
--
-- Dependencies:
--   - Works with hl7_parser.lua (structure: msg[SEG][rep][field][rep][component][subcomponent])
-- ====================================================================

local hl7_accessor = {}

-- Function: get
-- Input:
--   msg (table) - Parsed HL7 message
--   path (string) - HL7-style path e.g. "PID.5.2.1"
-- Output:
--   string or nil - Extracted value or nil if missing
function hl7_accessor.get(msg, path)
   local seg, field, component, subcomponent = path:match("^(%u+).(%d+)%.?(%d*)%.?(%d*)$")

   if not seg or not field then return nil end

   local segment = msg[seg]
   if not segment or not segment[1] then return nil end

   local fieldIndex = tonumber(field)
   local componentIndex = tonumber(component) or 1
   local subcomponentIndex = tonumber(subcomponent) or 1

   local fieldNode = segment[1][fieldIndex]
   if not fieldNode or not fieldNode[1] then return nil end

   local componentNode = fieldNode[1][componentIndex]
   if not componentNode then return nil end

   return componentNode[subcomponentIndex] or nil
end

return hl7_accessor