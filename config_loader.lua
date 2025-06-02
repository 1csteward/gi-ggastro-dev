-- ====================================================================
-- config_loader.lua
-- Author: Conor Steward
-- Date Created: 6/2/25
-- Last Edit: 6/2/25
--
-- Purpose:
-- Loads values from Iguana X's UI-managed config.json.
-- Fails fast if a required key is missing.
-- Provides a consistent way to access environment-configured settings.
--
-- Usage:
--   local config = require 'config_loader'
--   local url = config.get("lims_url")
--
-- Notes:
-- - Do not use default fallbacks here to ensure all config is explicit.
-- - All expected keys must be set in Iguana’s channel config.
-- ====================================================================

local json = require 'json'

local config_loader = {}

-- Parse the Iguana-managed config.json file
local rawConfig = json.parse(iguana.channelConfig():json()) or {}

-- Function: get
-- Purpose:
--   Retrieves a config value by key and errors if not found or empty.
--
-- Input:
--   key (string) - The name of the config value to retrieve
--
-- Output:
--   string - The value if found
--   error  - If the key is missing or empty
function config_loader.get(key)
   local value = rawConfig[key]

   if value == nil or value == "" then
      local msg = string.format("Missing required config value: '%s'", key)
      iguana.logError(msg)
      error(msg)
   end

   return value
end

-- Optional: get all values (useful for debugging/logging purposes)
function config_loader.all()
   return rawConfig
end

return config_loader
