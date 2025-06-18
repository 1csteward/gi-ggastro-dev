-- ====================================================================
-- api_client.lua
-- Author: Conor Steward
-- Date Created: 5/2/25
-- Last Edit: 6/18/25
--
-- Purpose:
--   Encapsulates HTTP POST logic for sending mapped HL7 data to the LIMS API.
--   - Dynamically posts eRequest and supporting table data to proper endpoints.
--   - Handles full "table:type" config values for routing and payload structure.
--   - Guards against nil HTTP response codes.
--
-- Dependencies:
--   - config_loader.lua (for credentials and endpoint URLs)
-- ====================================================================

local config_loader = require "config_loader"
local config = config_loader.load({
   "lims_table_url",
   "basic_auth",
   "timeout",
   "data_type_name"
})

local api_client = {}

-- ============================================================================
-- Function: sendToLims
-- Purpose : Sends a primary record (e.g., eRequest) to the LIMS table endpoint
-- Input   : payload (table)    - The mapped HL7 data for the main record
--           tableName (string) - Optional override for data_type_name
-- Output  : table              - Response { status, message }
-- ============================================================================
function api_client.sendToLims(payload, tableName)
   local limsUrlBase = config.lims_table_url:gsub("/+$", "")
   local authHeader = "Basic " .. config.basic_auth
   local timeout = tonumber(config.timeout or "10")

   local fullDataTypeName = tableName or config.data_type_name
   local baseTableName = fullDataTypeName:match("^(.-):") or fullDataTypeName

   local url = string.format("%s/%s", limsUrlBase, baseTableName)

   local success, response = pcall(function()
      return net.http.post{
         url     = url,
         headers = {
            ["Authorization"] = authHeader,
            ["Content-Type"]  = "application/json",
            ["Accept"]        = "application/json"
         },
         body    = json.serialize{
            data = {
               dataTypeName = fullDataTypeName,
               fields       = payload
            }
         },
         timeout = timeout
      }
   end)

   if not success then
      iguana.logError("Failed to POST to LIMS (" .. fullDataTypeName .. "): " .. tostring(response))
      return { status = 500, message = "Internal error", error = response }
   end

   if not response.code then
      iguana.logError("No HTTP status code received from LIMS response for " .. baseTableName)
      iguana.logError("Response object: " .. tostring(response))
      return { status = 500, message = "No status code from LIMS", error = response }
   elseif response.code >= 300 then
      iguana.logWarning(string.format("LIMS POST to %s failed (%d): %s", baseTableName, response.code, response.body or "No body"))
   else
      iguana.logInfo("Successfully posted " .. baseTableName .. " to LIMS")
   end

   return {
      status  = response.code,
      message = response.body
   }
end

-- ============================================================================
-- Function: sendSupportingTables
-- Purpose : Sends auxiliary tables (e.g., Patient, Physician) to LIMS
-- Input   : tableMap (table) - Table of key=tableName, value=fields
-- Output  : table            - Aggregate result { status, details }
-- ============================================================================
function api_client.sendSupportingTables(tableMap)
   local limsUrlBase = config.lims_table_url:gsub("/+$", "")
   local authHeader = config.basic_auth
   local timeout = tonumber(config.timeout or "10")

   local result = {}
   local allSucceeded = true

   for tableName, fields in pairs(tableMap) do
      if fields then
         local fullDataTypeName = tableName
         local baseTableName = tableName:match("^(.-):") or tableName
         local url = string.format("%s/%s", limsUrlBase, baseTableName)

         local success, response = pcall(function()
            return net.http.post{
               url     = url,
               headers = {
                  ["Authorization"] = authHeader,
                  ["Content-Type"]  = "application/json",
                  ["Accept"]        = "application/json"
               },
               body    = json.serialize{
                  data = {
                     dataTypeName = fullDataTypeName,
                     fields       = fields
                  }
               },
               timeout = timeout
            }
         end)

         if not success then
            result[baseTableName] = { status = 500, message = "Internal error", error = response }
            iguana.logError("Failed to POST to LIMS (" .. fullDataTypeName .. "): " .. tostring(response))
            allSucceeded = false
         elseif not response.code then
            result[baseTableName] = { status = 500, message = "No status code", error = response }
            iguana.logError("No HTTP status code received for table " .. baseTableName)
            iguana.logError("Response object: " .. tostring(response))
            allSucceeded = false
         elseif response.code >= 300 then
            result[baseTableName] = { status = response.code, message = response.body or "No body" }
            iguana.logWarning("POST to LIMS (" .. fullDataTypeName .. ") failed: " .. response.code)
            allSucceeded = false
         else
            result[baseTableName] = { status = response.code, message = response.body }
            iguana.logInfo("Successfully posted " .. baseTableName .. " to LIMS")
         end
      end
   end

   return {
      status  = allSucceeded and 200 or 500,
      details = result
   }
end

return api_client