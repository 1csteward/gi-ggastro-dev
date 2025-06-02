-- ====================================================================
-- queue_writer.lua
-- Author: Conor Steward
-- Date Created: 6/2/25
--
-- Purpose:
-- Writes structured HL7 or mapped data into a designated Iguana queue.
-- Used to decouple message ingestion from downstream processing.
--
-- Usage:
--   local q = require 'queue_writer'
--   q.enqueue(data, "ingest_queue") -- Optional: specify queue name
--
-- Dependencies:
--   - config_loader.lua (for default queue name if not provided)
-- ====================================================================

local queue_writer = {}

local json = require 'json'
local config = require 'config_loader'

-- Function: enqueue
-- Purpose:
--   Pushes data to an Iguana queue as serialized JSON with timestamp.
--
-- Input:
--   payload (table) - Structured HL7 or mapped LIMS data
--   queueName (string, optional) - Destination queue name (fallback to config or default)
function queue_writer.enqueue(payload, queueName)
   local name = queueName or config.get("ingest_queue") or "hl7_ingest_queue"

   local envelope = {
      timestamp = os.ts(),
      data = payload
   }

   queue.push{
      name = name,
      data = json.serialize(envelope)
   }

   iguana.logInfo("Message enqueued to '" .. name .. "'")
end

return queue_writer
