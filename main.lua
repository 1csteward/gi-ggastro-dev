-- ============================================================================
-- main.lua
-- Author: Conor Steward
-- Updated: 6/18/25
--
-- Purpose:
--   Ingest HL7 messages from a From LLP channel.
--   - Normalizes HL7 input.
--   - Parses with VMD.
--   - Maps with hl7_mapper into VDB structure.
--   - Sends primary table to main LIMS endpoint.
--   - Sends supporting tables to LIMS table endpoint.
--   - Handles retry logic and logging.
-- ============================================================================

-- Required modules
local hl7_mapper      = require "hl7_mapper"
local api_client      = require "api_client"
local retry_processor = require "retry_processor"
local queue_writer    = require "queue_writer"
local config_loader   = require "config_loader"

-- Load config file values
local config = config_loader.load({
   "lims_table_url",
   "basic_auth",
   "timeout",
   "max_retries",
   "data_type_name"
})

-- Extract config values
local data_type_name = config.data_type_name

-- ============================================================================
-- normalizeHL7
-- Cleans and validates the HL7 input string
-- ============================================================================
local function normalizeHL7(raw)
   local msg = raw:gsub("\r\n", "\r"):gsub("\n", "\r"):match("^%s*(.-)%s*$")
   if not msg:match("^MSH|") then
      iguana.logError("Invalid HL7 format: missing MSH segment")
      error("HL7 must begin with MSH segment")
   end
   return msg
end

-- ============================================================================
-- extractMetadata
-- Grabs message control ID and message type from MSH
-- ============================================================================
local function extractMetadata(msg)
   local eventId = msg.MSH[10] and msg.MSH[10]:S() or util.guid()
   local messageType = (msg.MSH[9][1] and msg.MSH[9][1]:S() or "") .. "_" .. (msg.MSH[9][2] and msg.MSH[9][2]:S() or "UNKNOWN")
   return eventId, messageType
end

-- ============================================================================
-- processMessage
-- Handles full flow of parsing, mapping, and sending HL7 message
-- ============================================================================
local function processMessage(raw)
   iguana.logInfo("Starting HL7 message processing")

   local cleaned = normalizeHL7(raw)

   local parsed = hl7.parse{
      vmd  = "lab_orders.vmd",
      data = cleaned
   }

   local eventId, messageType = extractMetadata(parsed)
   local mapped = hl7_mapper.map(parsed)

   -- Send primary table using config-defined data_type_name (e.g., "eRequest:eRequest")
   local okMain, resMain = pcall(function()
      return api_client.sendToLims(mapped.eRequest, data_type_name)
   end)

   if not okMain or not resMain or not resMain.status then
      retry_processor.handleRetry(mapped.eRequest, "Failed primary table submission", config, 1)
      iguana.logError("Primary table submission failed")
   elseif resMain.status >= 300 then
      retry_processor.handleRetry(mapped.eRequest, "Primary table submission status " .. resMain.status, config, 1)
      iguana.logWarning("Primary table HTTP status: " .. resMain.status)
   else
      iguana.logInfo("Primary table submission succeeded")
   end

   -- Define and send supporting tables using full dataTypeName format
   local supportingTables = {
      ["Patient:Patient"]      = mapped.Patient,
      ["Physician:Physician"]  = mapped.Physician,
      ["Organization:Org"]     = mapped.Organization,
      ["HL7Datum:HL7Datum"]    = mapped.HL7Datum
   }

   local okTables, resTables = pcall(function()
      return api_client.sendSupportingTables(supportingTables)
   end)

   if not okTables or not resTables or not resTables.status then
      iguana.logWarning("Supporting tables submission failed")
   elseif resTables.status >= 300 then
      iguana.logWarning("Supporting tables HTTP status: " .. resTables.status)
   else
      iguana.logInfo("Supporting table data submitted successfully")
      queue_writer.pushToQueue(mapped)
   end

   return cleaned
end

-- ============================================================================
-- main
-- Entry point for HL7 message processing
-- ============================================================================
function main(Data)
   local ok, err = pcall(function()
      processMessage(Data)
   end)

   if not ok then
      iguana.logError("Message processing failed with error: " .. tostring(err))
      iguana.logError("Raw HL7: " .. Data)
   else
      iguana.logInfo("HL7 message processed successfully.")
   end
end