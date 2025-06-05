-- ====================================================================
-- audit_log.lua
-- Author: Conor Steward
-- Date Created: 6/2/25
-- Last Edit: 6/2/25
--
-- Purpose:
-- Records high-level integration activity (e.g., success, retry, drop).
-- Structured logs for traceability and compliance.
--
-- Usage:
--   local audit = require 'audit_log'
--   audit.success("Posted to LIMS", {patient = "Jane Doe", recordId = 12345})
--
-- Notes:
-- - Designed to complement error_handler.lua
-- - Can be extended to persist to file/db if needed
-- ====================================================================

local audit_log = {}

-- Function: success
-- Purpose:
--   Log a successful integration event
-- Input:
--   message (string) - Description of event
--   context (table) - Optional metadata (recordId, patientName, etc.)
function audit_log.success(message, context)
   local entry = {
      level = "SUCCESS",
      timestamp = os.ts(),
      message = message,
      context = context or {}
   }
   iguana.logInfo(json.serialize(entry):gsub("\n", ""))
end

-- Function: retry
-- Purpose:
--   Log a retry attempt
function audit_log.retry(message, context)
   local entry = {
      level = "RETRY",
      timestamp = os.ts(),
      message = message,
      context = context or {}
   }
   iguana.logWarning(json.serialize(entry):gsub("\n", ""))
end

-- Function: dropped
-- Purpose:
--   Log a permanently dropped message (e.g., exceeded max retries)
function audit_log.dropped(message, context)
   local entry = {
      level = "DROPPED",
      timestamp = os.ts(),
      message = message,
      context = context or {}
   }
   iguana.logError(json.serialize(entry):gsub("\n", ""))
end

return audit_log
