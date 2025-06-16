-- ====================================================================
-- api_client.lua
-- Author: Conor Steward
-- Date Created: 5/2/25
-- Last Edit: 6/12/25
--
-- Purpose:
--   Encapsulates HTTP POST logic for sending data to the LIMS API.
--   Supports Basic Auth and configurable object types via data_type_name.
--
-- Dependencies:
--   - config_loader.lua (for credentials and type mappings)
-- ====================================================================

local config_loader = require "config_loader"
local config = config_loader.load({ "lims_url", "basic_auth", "timeout", "data_type_name" })

local api_client = {}

-- ============================================================================
-- Function: sendToLims
-- Purpose : Sends mapped HL7 fields to the LIMS eRequest API
-- Input   : data (table) - Mapped HL7 data
-- Output  : table - {status, body, error}
-- ============================================================================
function api_client.sendToLims(data)
   local url = config.lims_url
   local auth = config.basic_auth
   local timeout = tonumber(config.timeout or "10")

   local headers = {
      ["Authorization"] = auth,
      ["Content-Type"] = "application/json",
      ["Accept"] = "application/json"
   }

   local success, response = pcall(function()
      return net.http.post{
         url     = url,
         headers = headers,
         body    = json.serialize{data = data},
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

-- ============================================================================
-- Function: sendHL7RawMessage
-- Purpose : Posts raw HL7 message to HL7RawMessage object in LIMS
-- Input   : eventId, rawMessage, messageType, source, typeName (string)
-- Output  : parsed LIMS response or nil
-- ============================================================================
function api_client.sendHL7RawMessage(eventId, rawMessage, messageType, source, typeName)
   local url = config.lims_url
   local auth = config.basic_auth
   local timeout = tonumber(config.timeout or "10")

   local body = {
      dataTypeName = typeName,
      fields = {
         EventID     = eventId,
         RawMessage  = rawMessage,
         Source      = source or "IguanaX",
         MessageType = messageType or "UNKNOWN",
         Timestamp   = os.time() * 1000
      }
   }

   local headers = {
      ["Content-Type"] = "application/json",
      ["Authorization"] = auth
   }

   local result, code, respHeaders, status = net.http.post{
      url     = url .. "/datarecord",
      headers = headers,
      body    = json.serialize(body),
      timeout = timeout
   }

   if code ~= 200 then
      iguana.logError("Failed to send HL7RawMessage: " .. tostring(result))
      return nil
   end

   return json.parse{data = result}
end

return api_client