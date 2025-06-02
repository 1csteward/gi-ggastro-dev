-- ====================================================================
-- hl7_parser.lua
-- Author: Conor Steward
-- Date Created: 6/2/25
-- Last Edit: 6/2/25
--
-- Purpose:
-- Parses HL7 v2.x messages into a nested Lua table.
-- Supports segments, fields, components (^), subcomponents (&), and repeats (~).
--
-- Notes:
-- - Message structure: msg[segment][rep][field][rep][component][subcomponent]
-- - Assumes default HL7 delimiters: | ^ ~ \ &
-- ====================================================================

local hl7_parser = {}

-- Utility function: split
-- Splits a string into parts by a given delimiter.
-- Input:
--   str (string) - Original string
--   delimiter (string) - Character to split by
-- Output:
--   table - List of substrings
local function split(str, delimiter)
   local result = {}
   for match in (str .. delimiter):gmatch("(.-)" .. delimiter) do
      table.insert(result, match)
   end
   return result
end

-- Function: parse
-- Converts raw HL7 string into nested Lua table structure.
-- Handles segments, fields, components, subcomponents, and repetitions.
-- Input:
--   raw (string) - Raw HL7 message
-- Output:
--   table - Parsed HL7 structure
function hl7_parser.parse(raw)
   local msg = {}
   local fieldSep = "|"
   local componentSep = "^"
   local repeatSep = "~"
   local subcomponentSep = "&"

   for segmentLine in raw:gmatch("[^\r\n]+") do
      local rawFields = split(segmentLine, fieldSep)
      local fields = {}

      for fieldIndex, field in ipairs(rawFields) do
         local fieldRepeats = {}

         for rep in field:gmatch("[^" .. repeatSep .. "]+") do
            local components = {}
            for _, comp in ipairs(split(rep, componentSep)) do
               local subcomponents = split(comp, subcomponentSep)
               table.insert(components, subcomponents)
            end
            table.insert(fieldRepeats, components)
         end

         table.insert(fields, fieldRepeats)
      end

      local segName = rawFields[1]
      if not msg[segName] then msg[segName] = {} end
      table.insert(msg[segName], fields)
   end

   return msg
end

return hl7_parser