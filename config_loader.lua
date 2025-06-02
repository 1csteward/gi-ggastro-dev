-- ====================================================================
-- config_loader.lua
-- Author: Conor Steward
-- Date Created: 6/2/25
-- Last Edit: 6/2/25
--
-- Purpose:
-- Loads static test configuration for Iguana X.
-- Replace with environment-driven config for production deployments.
--
-- Usage:
--   local config = require 'config_loader'
--   local url = config.get("lims_url")
--
-- Notes:
-- - Iguana X does not support iguana.channelConfig or iguana.json.
-- - This version uses hardcoded values for local simulation only.
-- ====================================================================

local config_loader = {}

-- Static test config values
local rawConfig = {
   lims_url = "https://newstage.clabsportal.com:8020/webservice/api/datarecordlist/fields/eRequest",
   basic_auth = "Basic Y3N0ZXdhcmQ6RmxhZ3N0YWZmZXJhMjUh",
   timeout = "10",
   max_retries = "3"
}

-- Function: get
-- Purpose:
--   Retrieves a config value by key. Fails fast if missing or empty.
function config_loader.get(key)
   local value = rawConfig[key]
   if value == nil or value == "" then
      local msg = string.format("Missing required config value: '%s'", key)
      iguana.logError(msg)
      error(msg)
   end
   return value
end

-- Optional: dump all config (for debugging)
function config_loader.all()
   return rawConfig
end

return config_loader
