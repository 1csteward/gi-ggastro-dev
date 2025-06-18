-- ================================================================
-- config_loader.lua
-- Author: Conor Steward
-- Date Created: 5/5/25
-- Last Edit: 6/12/25
--
-- Purpose:
-- Provides centralized access to Iguana X Translator UI-defined custom
-- configuration fields using the `component.fields()` API.
-- Ensures all required keys are present and returns a config table.
-- Adds utility to parse key-value CSV mappings (e.g. data_type_name).
--
-- Usage:
--   local config = config_loader.load({ "lims_url", "basic_auth", "timeout" })
--   local typeName = config_loader.getDataTypeName("raw")
-- ================================================================

local config_loader = {}

-- Internal cache for component fields
local rawConfig = component.fields()

-- ============================================================================
-- Function: load
-- Purpose : Load only the requested config keys
-- ============================================================================
function config_loader.load(requiredKeys)
   local config = {}

   for _, key in ipairs(requiredKeys) do
      local value = rawConfig[key]
      if value == nil or value == '' then
         local msg = string.format("Missing required config value: '%s'", key)
         iguana.logError(msg)
         error(msg)
      end
      config[key] = value
   end

   return config
end

-- ============================================================================
-- Function: getDataTypeName
-- Purpose : Extracts a specific type name from a CSV-style config string
-- Input   : key (e.g. "raw", "erequest")
-- Returns : value (e.g. "HL7RawMessage")
-- ============================================================================
function config_loader.getDataTypeName(key)
   local csv = rawConfig["data_type_name"]
   if not csv then
      error("Missing config value: 'data_type_name'")
   end

   for pair in csv:gmatch("[^,]+") do
      local k, v = pair:match("^%s*(.-)%s*:%s*(.-)%s*$")
      if k == key then
         return v
      end
   end

   error("Type key '" .. key .. "' not found in 'data_type_name' config")
end

return config_loader