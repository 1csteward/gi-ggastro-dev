-- ============================================================================
-- main.lua
-- Author: Conor Steward
-- Updated: 6/13/25
--
-- Purpose:
--   Entry point for HL7 messages received via From LLP channel.
--   - Sanitizes and validates HL7 string format.
--   - Parses HL7 message using a VMD file.
--   - Maps parsed message to a LIMS-compatible table using hl7_mapper.
--   - Sends both raw and mapped data to LIMS endpoints.
--   - Handles retries, error logging, and auditing.
-- ============================================================================

-- Dependencies
local hl7_mapper      = require "hl7_mapper"
local api_client      = require "api_client"
local retry_processor = require "retry_processor"
local config_loader   = require "config_loader"

-- Load required config fields
local config = config_loader.load({
   "lims_url", "basic_auth", "timeout", "max_retries", "data_type_name"
})

-- ============================================================================
-- Function: sanitizeHL7
-- Purpose : Normalize incoming HL7 string:
--           - Trim whitespace
--           - Normalize line endings to HL7 standard carriage returns (\r)
--           - Ensure message begins with MSH|
-- ============================================================================
local function sanitizeHL7(raw)
   local cleaned = raw:gsub("\r\n", "\r"):gsub("\n", "\r"):match("^%s*(.-)%s*$")
   if not cleaned:match("^MSH|") then
      error_handler.log("Invalid HL7 format: missing MSH segment", { raw = raw }, "error")
      error("HL7 must start with MSH segment")
   end
   return cleaned
end

-- ============================================================================
-- Function: extractHL7Metadata
-- Purpose : Extracts event ID and message type from the parsed HL7 MSH segment
-- Input   : msg - Parsed HL7 message (Lua table)
-- Output  : eventId (string), messageType (string)
-- ============================================================================
local function extractHL7Metadata(msg)
   local eventId = msg.MSH[1]["Message Control ID"] and msg.MSH[1]["Message Control ID"]:S() or util.guid()
   local mt = msg.MSH[1]["Message Type"]
   local messageType = (mt[1] and mt[1]:S() or "") .. "_" .. (mt[2] and mt[2]:S() or "UNKNOWN")
   return eventId, messageType
end

-- ============================================================================
-- Function: processMessage
-- Purpose : Core HL7 ingestion pipeline for single message
-- Input   : raw - Raw HL7 string
-- Output  : cleaned - Cleaned HL7 string for ACK response
-- ============================================================================
local function processMessage(raw)
   iguana.logInfo("Starting HL7 message processing")

   -- Step 1: Clean input HL7 string
   local cleaned = sanitizeHL7(raw)

   -- Step 2: Parse with VMD
   local parsedMsg = hl7.parse{
      vmd = "lab_orders.vmd",
      data = cleaned
   }

   -- Step 3: Extract metadata for logging
   local eventId, messageType = extractHL7Metadata(parsedMsg)

   -- Step 4: Map to flat LIMS-compatible table
   local mapped = hl7_mapper.map(parsedMsg)

   -- Step 5: Archive raw HL7 message to LIMS
   local okRaw, errRaw = pcall(function()
      local typeName = config_loader.getDataTypeName("raw")
      api_client.sendHL7RawMessage(eventId, cleaned, messageType, "gGastro", typeName)
   end)
   if not okRaw then
      error_handler.log("Failed to post raw HL7 to LIMS", { eventId = eventId, error = errRaw }, "warning")
   end

   -- Step 6: Submit structured data to LIMS API
   local response = api_client.sendToLims(mapped)
   if not response or not response.status then
      error_handler.log("LIMS API returned no status", { response = response, mapped = mapped }, "error")
      error("LIMS API submission failed: No status returned")
   end

   -- Step 7: Success or retry
   if response.status >= 300 then
      retry_processor.enqueue(mapped, "Initial LIMS submission failed")
      audit_log.retry("LIMS submission failed", { status = response.status })
   else
      audit_log.success("LIMS submission succeeded", {
         status = response.status,
         patient = (mapped.PatientFirstName or "") .. " " .. (mapped.PatientLastName or "")
      })
   end

   return cleaned
end

-- ============================================================================
-- Function: main
-- Purpose : Iguana From LLP channel entry point
-- Input   : Data - Raw HL7 string from channel
-- ============================================================================
function main(Data)
   local ok, err = pcall(function()
      processMessage(Data)
   end)

   if ok then
      iguana.logInfo("HL7 message processed and posted successfully.")
   else
      iguana.logError("Message processing failed", { raw = Data, error = err }, "error")
      iguana.logError("Processing failed: " .. tostring(err))
   end
end