--==================================================
-- api_client.lua
-- Purpose: Handles all HTTP interactions with Exemplar LIMS API.
--==================================================

local http = require 'net.http'
local json = require 'json'
local config = require 'config_loader'

local api_client = {}

--==================================================
-- Submit a lab order to Exemplar LIMS (eRequest endpoint)
-- @param orderTable (table): Lua table representing the order
-- @returns (string): API response body
--==================================================
function api_client.submitOrder(orderTable)
   local cfg = config.getLimsConfig()

   local body = json.serialize(orderTable)  -- or just {} if sending nothing
   local headers = {
      ['Authorization'] = cfg.authHeader, -- 'Basic ZW5jb2RlZA==' format
      ['Accept'] = 'application/json',
      ['Content-Type'] = 'application/json'
   }

   local response, code = http.post {
      url = cfg.url,
      headers = headers,
      body = body,
      timeout = 5000,
      live = true
   }

   if code ~= 200 and code ~= 201 then
      error('API submission failed: HTTP ' .. code .. '\n' .. response)
   end

   return response
end

return api_client