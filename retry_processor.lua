--==================================================
-- retry_processor.lua
-- Conor Steward 4/29/25
-- Purpose: Process previously failed payloads queued on disk and retry sending them to the API.
-- Issues: No known issues.
--==================================================

local retry_processor = {}
local json = require 'json'
local api = require 'api_client'
local audit = require 'audit_log'
local error_handler = require 'error_handler'

-- Path to where queued files are stored
local queueDir = '/path/to/queue/folder/'  -- Same as queue_writer.lua

--==================================================
-- Process all queued JSON files
--==================================================
function retry_processor.processQueue()
   local Success, ErrMsg = pcall(function()
      local files = retry_processor.listQueuedFiles()

      -- Loops through queued files for retrying
      for _, filename in ipairs(files) do
         local fullPath = queueDir .. filename
         
         local file = io.open(fullPath, 'r')
         if file then
            local contents = file:read("*a")
            file:close()
            
            -- Stores file contents in OrderPayLoad
            local OrderPayload = json.parse{data = contents}
            
            -- Retries order
            local ApiSuccess, ApiErr = pcall(function()
               api.submitOrder(OrderPayload)
            end)

            if ApiSuccess then
               os.remove(fullPath)
               audit.logSuccess('Successfully resent queued order', filename)
            else
               error_handler.logFailure('Failed retry for queued order', ApiErr)
               -- Note: Do NOT delete the file if still failing.
            end
         else
            error_handler.logFailure('Failed to read queued file', filename)
         end
      end
   end)

   if not Success then
      error_handler.logFailure('Fatal error during queue processing', ErrMsg)
   end
end

--==================================================
-- List all queued JSON files
-- @returns (table): List of file names
--==================================================
function retry_processor.listQueuedFiles()
   local files = {}
   local p = io.popen('ls "'..queueDir..'"')

   if p then
      for file in p:lines() do
         if file:match("%.json$") then
            table.insert(files, file)
         end
      end
      p:close()
   else
      error('Could not open queue directory.')
   end

   return files
end

return retry_processor