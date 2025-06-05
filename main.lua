-- ============================================================================
-- main.lua
-- Author: Conor Steward
-- Updated: 6/4/25
-- Purpose:
--   Entry point for messages from a From LLP channel.
--   Parses, validates, maps HL7 messages and submits to LIMS API.
-- ============================================================================

-- Required modules
local hl7_accessor = require "hl7_accessor"
local hl7_parser = require "hl7_parser"
local hl7_mapper = require "hl7_mapper"
local validator = require "validator"
local api_client = require "api_client"
local retry_processor = require "retry_processor"
local error_handler = require "error_handler"
local audit_log = require "audit_log"

-- Load configuration fields from component config.json (UI-managed)
local config_loader = require "config_loader"
local config = config_loader.load({"lims_url", "basic_auth", "timeout", "max_retries"})

-- Function: processMessage
-- Purpose: Main HL7 → LIMS processing pipeline
-- Returns: HL7 ACK string on success
function processMessage(raw)
   iguana.logInfo("Starting HL7 message processing")

   local parsed = hl7_parser.parse(raw)
   if not parsed then error("Failed to parse HL7 message") end

   local validationErrors = validator.basicValidate(parsed)
   if #validationErrors > 0 then
      error_handler.log("Validation failed", { errors = validationErrors }, "warning")
      error("Message failed validation")
   end

   local mapped = hl7_mapper.map(parsed)
   iguana.logInfo("Mapped HL7 to LIMS fields:\n" .. json.serialize(mapped))

   local response = api_client.sendToLims(mapped)
   iguana.logInfo("LIMS response: " .. tostring(response.status))

   if response.status >= 300 then
      retry_processor.enqueue(mapped, "Initial LIMS submission failed")
      audit_log.retry("LIMS submission failed", { status = response.status })
   else
      audit_log.success("LIMS submission succeeded", {
         status = response.status,
         patient = mapped.PatientFirstName .. " " .. mapped.PatientLastName
      })
   end

   -- Return nil to let Iguana generate a standard ACK automatically
   return raw  -- Echoing original message is valid too if needed
end

-- Iguana calls this function automatically for each LLP message
function main(Data)
   local ok, result = pcall(function()
      return processMessage(Data)
   end)

   if ok then
      iguana.logInfo("Message %s sent successfully.")
   else
      iguana.logError("Processing error: " .. tostring(result))
   end
end
