require "hl7_accessor"
-- ========================================================================
-- main.lua
-- Author: Conor Steward
-- Date Created: 5/27/25
-- Last Edit: 6/2/25
--
-- Purpose:
-- Handles HL7 message ingestion from gGastro via MLLP or test input.
-- Parses, validates, maps, submits to LIMS, and returns HL7 ACK/NACK.
--
-- Notes:
-- For testing: call processMessage(rawHL7) directly.
-- For production: call main() to start LLP listener.
-- =========================================================================

-- Imports
local hl7_parser = require 'hl7_parser'
local hl7_mapper = require 'hl7_mapper'
local validator = require 'validator'
local api_client = require 'api_client'
local retry_processor = require 'retry_processor'
local error_handler = require 'error_handler'
local audit_log = require 'audit_log'

-- Function: processMessage
-- Purpose: Handles the full HL7 processing pipeline for one message.
-- Input: raw (string) - Raw HL7 message string
-- Output: string - HL7 ACK message string
function processMessage(raw)
   local parsed = hl7_parser.parse(raw)
   if not parsed then error("Failed to parse HL7 message") end

   local validationErrors = validator.basicValidate(parsed)
   if #validationErrors > 0 then
      error_handler.log("Validation failed", { errors = validationErrors }, "warning")
      error("Message failed validation")
   end

   local mapped = hl7_mapper.map(parsed)
   local response = api_client.sendToLims(mapped)

   if response.status >= 300 then
      retry_processor.enqueue(mapped, "Initial API submission failed")
      audit_log.retry("Initial LIMS API submission failed", { status = response.status })
   else
      audit_log.success("Posted to LIMS", {
         status = response.status,
         patient = mapped.PatientFirstName .. " " .. mapped.PatientLastName
      })
   end

   local ackMsg = hl7.message{}
   ackMsg:appendSegment("MSH")
   ackMsg.MSH[1] = "|"
   ackMsg.MSH[2] = "^~\\&"
   ackMsg.MSH[3] = parsed.MSH[5]
   ackMsg.MSH[4] = parsed.MSH[6]
   ackMsg.MSH[5] = parsed.MSH[3]
   ackMsg.MSH[7] = os.date('%Y%m%d%H%M%S')
   ackMsg.MSH[9][1] = "ACK"
   ackMsg.MSH[10] = parsed.MSH[10]
   ackMsg.MSH[11][1]= "P"
   ackMsg.MSH[12] = "2.3"

   ackMsg:appendSegment("MSA")
   ackMsg.MSA[1] = "AA"
   ackMsg.MSA[2] = parsed.MSH[10]

   return ackMsg:S()
end

-- Function: main
-- Purpose: LLP listener mode for receiving HL7 messages in production.
-- Comment this out during test-driven development.
function main()
   -- Uncomment the block below for production mode (MLLP listener)
   --[[
   local port = 5140
   local server = llp.listen{ port = port, timeout = 30 }
   iguana.logInfo("Listening for HL7 messages on port " .. port)

   while true do
      local conn = server:accept()
      local hl7Raw = conn:recv()

      if not hl7Raw then
         error_handler.log("No message received. Connection may have timed out.", nil, "warning")
         break
      end

      local success, ack = pcall(function()
         return processMessage(hl7Raw)
      end)

      if success then
         conn:send(ack)
         iguana.logInfo("ACK sent successfully")
      else
         error_handler.log("Processing error", { reason = ack }, "error")

         local nack = hl7.message{}
         nack:appendSegment("MSH")
         nack.MSH[1] = "|"
         nack.MSH[2] = "^~\\&"
         nack.MSH[3] = "gGastro"
         nack.MSH[5] = "Castle Biosciences"
         nack.MSH[7] = os.date('%Y%m%d%H%M%S')
         nack.MSH[9][1] = "ACK"
         nack.MSH[10] = os.time()
         nack.MSH[11][1] = "P"
         nack.MSH[12] = "2.3"

         nack:appendSegment("MSA")
         nack.MSA[1] = "AE"
         nack.MSA[2] = "N/A"

         conn:send(nack:S())
         iguana.logInfo("NACK sent due to processing error")
      end
   end
   --]]

   -- Uncomment the block below during testing to simulate test data input
   -- Example:
   -- local test = require 'test.test_runner'
   -- test.testAll()
end