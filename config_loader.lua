-- ================================================================
-- config_loader.lua
-- Author: Conor Steward
-- Date Created: 6/2/25
-- Last Edit: 6/4/25
--
-- Purpose:
-- Provides centralized access to Iguana X Translator UI-defined custom
-- configuration fields using the `component.fields()` API.
-- Ensures all required keys are present and returns a config table.
--
-- Usage:
--   local config_loader = require 'config_loader'
--   local config = config_loader.load({ 'lims_url', 'basic_auth', 'test_mode' })
--
-- Notes:
-- `component.fields()` is Iguana X-native.
-- test_mode is returned as a boolean.
-- ================================================================

local config_loader = {}

-- Loads and validates only the specified config keys
function config_loader.load(requiredKeys)
   local fields = component.fields()
   local config = {}

   for _, key in ipairs(requiredKeys) do
      local value = fields[key]
      if value == nil or value == '' then
         local msg = string.format("Missing required config value: '%s'", key)
         iguana.logError(msg)
         error(msg)
      end

      -- Coerce 'true'/'false' strings into booleans for known toggles
      if key == "test_mode" then
         config[key] = (value == "true")
      else
         config[key] = value
      end
   end

   return config
end

return config_loader