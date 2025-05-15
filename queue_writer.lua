--==================================================
-- queue_writer.lua
-- Purpose: Safely enqueue failed API payloads for later processing.
--==================================================

local queue_writer = {}
local json = require 'json'

--==================================================
-- Enqueue payload if API submission fails
-- @param payload (table): Order payload to save
--==================================================
function queue_writer.enqueue(payload)
   local queueDir = '/path/to/queue/folder/'  -- Replace with protected folder. Same as retry_processor.
   local fileName = os.ts.date('%Y%m%d%H%M%S') .. '_' .. math.random(1000,9999) .. '.json'

   local file = io.open(queueDir .. fileName, 'w')
   if file then
      file:write(json.serialize{data = payload})
      file:close()
   else
      error('Failed to write queued order: ' .. fileName)
   end
end

return queue_writer