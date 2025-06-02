-- ====================================================================
-- retry_processor.lua
-- Author: Conor Steward
-- Date Created: 6/2/25
-- Last Edit: 6/2/25
--
-- Purpose:
-- Handles retry logic for failed LIMS API submissions.
-- Uses Iguana queue to re-attempt sending on failure.
--
-- Usage:
--   local retry = require 'retry_processor'
--   retry.enqueue(data, reason)
--   retry.processQueue()
--
-- Dependencies:
--   - api_client.lua
--   - config_loader.lua (for retry limits, etc.)
-- ====================================================================

local retry_processor = {}

local api_client = require 'api_client'
local json = 'iguana.json'
local config = require 'config_loader'

-- Constants
local MAX_RETRIES = tonumber(config.get("max_retries") or "3")
local RETRY_QUEUE = "lims_retry_queue"

-- Function: enqueue
-- Purpose:
--   Stores a failed payload in the retry queue with retry count and reason.
--
-- Input:
--   data (table) - Mapped HL7 data to retry
--   reason (string) - Optional reason for failure (logged for traceability)
function retry_processor.enqueue(data, reason)
   local envelope = {
      attempt = 1,
      timestamp = os.ts(),
      data = data,
      reason = reason or "Unspecified error"
   }

   queue.push{data = json.serialize(envelope), name = RETRY_QUEUE}
   iguana.logInfo("Queued message for retry. Reason: " .. envelope.reason)
end

-- Function: processQueue
-- Purpose:
--   Dequeues messages, retries API submission, and requeues if needed.
function retry_processor.processQueue()
   queue.pop(RETRY_QUEUE, function(raw)
      local envelope = json.parse(raw)

      iguana.logInfo(string.format("Retry attempt #%d for message from %s", envelope.attempt, envelope.timestamp))

      local result = api_client.sendToLims(envelope.data)

      if result.status >= 200 and result.status < 300 then
         iguana.logInfo("Retry succeeded for message from " .. envelope.timestamp)
         return true -- Message processed successfully
      else
         envelope.attempt = envelope.attempt + 1
         envelope.reason = "Retry failed with status " .. tostring(result.status)

         if envelope.attempt > MAX_RETRIES then
            iguana.logError("Retry exhausted. Dropping message from " .. envelope.timestamp)
            -- Optional: store to long-term archive or alert
            return true -- Drop from queue
         else
            iguana.logWarning("Retry failed, requeuing (attempt " .. envelope.attempt .. ")")
            queue.push{data = json.serialize(envelope), name = RETRY_QUEUE}
            return true -- Remove original from queue
         end
      end
   end)
end

return retry_processor