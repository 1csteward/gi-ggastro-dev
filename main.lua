-- ===============================
-- main.lua
-- ===============================

local config_loader = require 'config_loader'

--testing API to LIMS
function main()
   local cfg = config_loader.getLimsConfig()

   iguana.logInfo("✅ LIMS URL: " .. cfg.url)
   iguana.logInfo("✅ Username: " .. cfg.username)
end