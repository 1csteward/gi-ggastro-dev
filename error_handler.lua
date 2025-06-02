-- ====================================================================
-- error_handler.lua
-- Author: Conor Steward
-- Date Created: 6/2/25
-- Last Edit: 6/2/25
--
-- Purpose:
-- Centralized utility for structured error logging and classification.
-- Intended to be used in main.lua and across modules for consistent logging.
--
-- Usage:
--   local err = require 'error_handler'
--   err.log("Validation failed", {stage="validation", payload=...}, "warning")
--
-- Notes:
-- - Does not throw. Use only for logging/reporting.
-- - Future: Can be expanded to notify, persist, or escalate errors.
-- ====================================================================

local json = require 'json'

local error_handler = {}

-- Function: log
-- Purpose:
--   Logs structured error or warning messages with optional metadata.
--
-- Input:
--   message (string) - Description of the issue
--   context (table) - Optional metadata (e.g., HL7 ID, payload, module)
--   level (string) - One of: "error", "warning", "info"
function error_handler.log(message, context, level)
   level = (level or "error"):lower()

   local prefix = "Error: "
   local logFn = iguana.logError

   if level == "warning" then
      prefix = "Warning: "
      logFn = iguana.logWarning
   elseif level == "info" then
      prefix = "Info: "
      logFn = iguana.logInfo
   end

   local output = {
      timestamp = os.ts(),
      message = message,
      context = context or {}
   }

   local fullLog = prefix .. json.serialize(output):gsub("\n", "")
   logFn(fullLog)
end

-- Function: simple
-- Purpose:
--   Shortcut for plain error logging without context
function error_handler.simple(message)
   iguana.logError("Error: " .. message)
end

return error_handler
