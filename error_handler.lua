--==================================================
-- error_handler.lua
-- Purpose: Handle and log errors in a standardized manner.
--==================================================

local error_handler = {}

--==================================================
-- Log an error occurrence
-- @param message (string): Error context
-- @param err (string|table): Specific error details
--==================================================
function error_handler.logFailure(message, err)
   iguana.logError(message .. '\nError Details: ' .. tostring(err))
end

return error_handler