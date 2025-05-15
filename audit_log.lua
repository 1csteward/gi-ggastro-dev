--==================================================
-- audit_log.lua
-- Purpose: Record successful transactions and messages.
--==================================================

local audit_log = {}

--==================================================
-- Log successful API call or processing step
-- @param message (string): High-level message
-- @param detail (string|table): Additional details
--==================================================
function audit_log.logSuccess(message, detail)
   iguana.logInfo(message .. '\n' .. tostring(detail))
end

return audit_log