-- ====================================================================
-- retry_processor.lua
-- Author: Conor Steward
-- Updated: 6/16/25
--
-- Purpose:
--   Handles retry logic for failed LIMS API submissions.
--   Uses Iguana's native queue.push() to requeue for retry.
--
-- Usage:
--   local retry = require 'retry_processor'
--   retry.handleRetry(payload, reason, config, currentAttempt)
--
-- Dependencies:
--   - api_client.lua
-- ====================================================================

local retry_processor = {}
local api_client = require 'api_client'

-- ====================================================================
-- Function: extractIdentifiers
-- Purpose : Pulls sender and message ID from HL7 data
-- Input   : data (table) - Mapped or parsed HL7 message
-- Returns : sender (string), messageId (string)
-- ====================================================================
local function extractIdentifiers(data)
   local msh = data.MSH or {}
   local sender = msh[3] or msh[4] or "UnknownSender"
   local msgId = msh[10] or "UnknownMsgID"

   -- If MSH fields are tables (from parsed HL7), get .1 component
   if type(sender) == "table" then
      sender = sender[1] or "UnknownSender"
   end
   if type(msgId) == "table" then
      msgId = msgId[1] or "UnknownMsgID"
   end

   return sender, msgId
end

-- ====================================================================
-- Function: handleRetry
-- Purpose : Sends message or requeues if under retry threshold
-- Input   :
--   data (table)        - Mapped HL7 payload
--   reason (string)     - Failure reason string
--   config (table)      - Loaded config with retry settings
--   attempt (number)    - Retry attempt number (default: 1)
-- ====================================================================
function retry_processor.handleRetry(data, reason, config, attempt)
   local retryLimit = tonumber(config.max_retries or 3)
   local currentAttempt = attempt or 1

   local sender, msgId = extractIdentifiers(data)

   iguana.logInfo(string.format(
      "Attempt #%d to resend message [Sender: %s, MessageControlID: %s]",
      currentAttempt, sender, msgId
   ))

   local result = api_client.sendToLims(data)

   if result.status >= 200 and result.status < 300 then
      iguana.logInfo(string.format(
         "Retry success after %d attempts [Sender: %s, MessageControlID: %s]",
         currentAttempt, sender, msgId
      ))
      return true
   end

   local nextAttempt = currentAttempt + 1
   local failureMsg = string.format(
      "Retry failed with status %s [Sender: %s, MessageControlID: %s]",
      tostring(result.status), sender, msgId
   )

   if nextAttempt > retryLimit then
      iguana.logError(string.format(
         "Retry limit reached (%d attempts). Dropping message. %s",
         retryLimit, failureMsg
      ))
      return false
   else
      iguana.logWarning(string.format(
         "%s. Requeuing for attempt #%d",
         failureMsg, nextAttempt
      ))

      local envelope = {
         attempt = nextAttempt,
         timestamp = os.ts(),
         data = data,
         reason = reason or failureMsg
      }

      queue.push{ data = json.serialize(envelope) }
      return true
   end
end

return retry_processor