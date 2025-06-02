-- ========================================================================
-- main.lua
-- Author: Conor Steward
-- Date Created: 5/27/25
-- Last Edit: 6/2/25
--
-- Purpose:
-- Listens for HL7 messages over MLLP (from NAT'd gGastro connection)
-- Parses, validates, maps, and submits to LIMS API
-- Sends back an HL7 ACK or NACK based on processing results
--
-- Notes:
-- Expects MLLP framing: 0x0B ... 0x1C0D
-- Dependencies: validator.lua, hl7_parser.lua, hl7_mapper.lua,
--                api_client.lua, retry_processor.lua, error_handler.lua,
--                audit_log.lua
-- =========================================================================

-- Imports
local hl7_parser = require 'hl7_parser'
local hl7_mapper = require 'hl7_mapper'
local validator = require 'validator'
local api_client = require 'api_client'
local retry_processor = require 'retry_processor'
local error_handler = require 'error_handler'
local audit_log = require 'audit_log'

function main()
   local port = 5140  -- Ensure this matches firewall/NAT rules
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
         local parsed = hl7_parser.parse(hl7Raw)
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
            audit_log.success("Posted to LIMS", { status = response.status, patient = mapped.PatientFirstName .. " " .. mapped.PatientLastName })
         end

         local ackMsg = hl7.message{}
         ackMsg:appendSegment("MSH")
         ackMsg.MSH[1] = "|"
         ackMsg.MSH[2] = "^~\\&"
         ackMsg.MSH[3] = parsed.MSH[5] -- receiving app becomes sending
         ackMsg.MSH[4] = parsed.MSH[6]
         ackMsg.MSH[5] = parsed.MSH[3] -- sending app becomes receiving
         ackMsg.MSH[7] = os.date('%Y%m%d%H%M%S')
         ackMsg.MSH[9][1] = "ACK"
         ackMsg.MSH[10] = parsed.MSH[10]
         ackMsg.MSH[11][1]= "P"
         ackMsg.MSH[12] = "2.3"

         ackMsg:appendSegment("MSA")
         ackMsg.MSA[1] = "AA"
         ackMsg.MSA[2] = parsed.MSH[10]

         return ackMsg:S()
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
end