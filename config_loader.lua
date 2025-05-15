-- config_loader.lua
-- Conor Steward 5/15/25
-- URL and credentials loaded from config.json
-- config_loader.lua
-- Loads config values from Iguana's config.json UI, with safe fallback.

local config_loader = {}

local config = nil
local ok, mod = pcall(require, 'config')
if ok then config = mod end

function config_loader.getLimsConfig()
   if config then
      return {
         url = config.LimsPostUrl(),
         username = config.username(),
         password = config.password()
      }
   else
      -- Fallback values (optional) for dev/testing
      iguana.logWarning("⚠️ 'config' module not found — using fallback credentials.")
      return {
         url = os.getenv("LIMS_POST_URL") or "https://example.com/fallback",
         username = os.getenv("LIMS_USER") or "fallback_user",
         password = os.getenv("LIMS_PASS") or "fallback_pass"
      }
   end
end

return config_loader