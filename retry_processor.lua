-- ====================================================================
-- retry_processor.lua
-- Author: Conor Steward
-- Date Created: 6/2/25
-- Last Edit: 6/4/25
--
-- Purpose:
-- Handles retry logic for failed LIMS API submissions.
-- Uses Iguana queue to re-attempt sending on failure.
--
-- Usage:
--   local retry = require 'retry_processor'
--   retry.enqueue(data, reason, config)
--   retry.processQueue(config)
--
-- Dependencies:
--   - api_client.lua
--   - config_loader.lua (caller passes loaded config)
-- ====================================================================

local retry_processor = {}

local api_client = require 'api_client'

-- Queue name constant
local RETRY_QUEUE = "lims_retry_queue"

-- Function: enqueue
-- Purpose:
--   Stores a failed payload in the retry queue with retry count and reason.
-- Input:
--   data (table) - Mapped HL7 data to retry
--   reason (string) - Failure reason (for logs)
--   config (table) - Loaded config table passed in from main
function retry_processor.enqueue(data, reason, config)
   local envelope = {
      attempt = 1,
      timestamp = os.ts(),
      data = data,
      reason = reason or "Unspecified error"
   }

   queue.push{data = json.serialize(envelope)}
   iguana.logInfo("Queued message for retry. Reason: " .. envelope.reason)
end

-- Function: processQueue
-- Purpose:
--   Processes queued retries and requeues if below max retry threshold.
-- Input:
--   config (table) - Loaded config table passed in from main
function retry_processor.processQueue(config)
   local maxRetries = tonumber(config.max_retries or 3)

   queue.pop(RETRY_QUEUE, function(raw)
      local envelope = json.parse(raw)

      iguana.logInfo(string.format("Retry attempt #%d for message from %s", envelope.attempt, envelope.timestamp))

      local result = api_client.sendToLims(envelope.data)

      if result.status >= 200 and result.status < 300 then
         iguana.logInfo("Retry succeeded for message from " .. envelope.timestamp)
         return true -- Processed successfully
      else
         envelope.attempt = envelope.attempt + 1
         envelope.reason = "Retry failed with status " .. tostring(result.status)

         if envelope.attempt > maxRetries then
            iguana.logError("Retry exhausted. Dropping message from " .. envelope.timestamp)
            return true -- Remove from queue
         else
            iguana.logWarning("Retry failed, requeuing (attempt " .. envelope.attempt .. ")")
            queue.push{data = json.serialize(envelope), name = RETRY_QUEUE}
            return true -- Remove old, re-add new
         end
      end
   end)
end

return retry_processor