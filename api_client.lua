-- ====================================================================
-- api_client.lua
-- Author: Conor Steward
-- Date Created: 6/2/25
-- Last Edit: 6/2/25
--
-- Purpose:
-- Encapsulates HTTP POST logic to send mapped HL7 data to the LIMS API.
-- Supports Basic Auth via base64-encoded credentials in Authorization header.
-- Can be extended to handle token-based auth later.
--
-- Usage:
--   local api = require 'api_client'
--   local response = api.sendToLims(mappedDataTable)
--
-- Dependencies:
--   - config_loader.lua (to manage base URL and auth string)
-- ====================================================================

local config = require "config_loader"

local api_client = {}

-- Function: sendToLims
-- Purpose:
--   Sends a JSON-formatted POST request to the LIMS API using Basic Auth.
--   Logs any transport or API errors and returns a response object for handling in main.
--
-- Input:
--   data (table) - A Lua table containing mapped HL7 values ready for submission
--
-- Output:
--   table - Response table containing:
--     - status (number): HTTP response code
--     - body (string): Raw response body (if available)
--     - error (any): Error detail if pcall fails
function api_client.sendToLims(data)
   local url = config.get("lims_url")
   local auth = config.get("basic_auth")
   local timeout = tonumber(config.get("timeout") or "10")

   local headers = {
      ["Authorization"] = auth,
      ["Content-Type"] = "application/json",
      ["Accept"] = "application/json"
   }

   local success, response = pcall(function()
      return iguana.http.post{
         url     = url,
         headers = headers,
         body    = json.serialize{data},
         timeout = timeout
      }
   end)

   if not success then
      iguana.logError("Failed to POST to LIMS API: " .. tostring(response))
      return {
         status = 500,
         body = "Internal error posting to LIMS",
         error = response
      }
   end

   if response.code >= 300 then
      iguana.logWarning(string.format("LIMS API returned status %d: %s", response.code, response.body or "No body"))
   else
      iguana.logInfo("Successfully posted to LIMS API")
   end

   return response
end

return api_client