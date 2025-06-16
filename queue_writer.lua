-- ====================================================================
-- queue_writer.lua
-- Author: Conor Steward
-- Updated: 6/16/25
--
-- Purpose:
--   Pushes structured HL7 or mapped LIMS data into the *current channel’s* Iguana queue.
--   Designed for use in Translator components that defer processing to the next stage.
--
--   Note: This uses the built-in queue.push function which only works when
--   the channel is running (not in test mode).
--
-- Usage:
--   local queue_writer = require 'queue_writer'
--   queue_writer.pushToQueue(data)
--
-- Returns:
--   A unique Message ID (format: YYYYMMDD-NNNNNNN)
-- ====================================================================

local queue_writer = {}

-- ====================================================================
-- Function: pushToQueue
-- Purpose : Push data into the current channel's queue as JSON
-- Input   : payload (table) - Any structured data (e.g., mapped HL7)
-- Returns : string - Unique Iguana Message ID (or nil if failed in test)
-- ====================================================================
function queue_writer.pushToQueue(payload)
   local envelope = {
      timestamp = os.ts(),
      data = payload
   }

   local ok, result = pcall(function()
      return queue.push{ data = json.serialize(envelope) }
   end)

   if ok then
      iguana.logInfo("Successfully pushed message to queue. Message ID: " .. result)
      return result
   else
      iguana.logWarning("Unable to push message to queue. Are you running in test mode?")
      return nil
   end
end

return queue_writer