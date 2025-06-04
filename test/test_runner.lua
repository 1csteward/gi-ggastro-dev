-- ====================================================================
-- test_runner.lua
-- Author: Conor Steward
-- Date Created: 6/2/25
-- Last Edit: 6/2/25
--
-- Purpose:
-- Executes predefined test cases against the HL7 ingestion pipeline.
-- Each test injects raw HL7 data into the main pipeline for validation,
-- parsing, mapping, and simulated ACK/NACK behavior.
--
-- Usage:
--   From Iguana Translator panel, call:
--     test_runner.testAll()
--
-- Notes:
-- - Test message files are .lua modules returning raw HL7 strings.
-- - main() must accept a string HL7 payload when testing.
-- - Useful for verifying interface integrity during development.
-- ====================================================================

local test_runner = {}
local processor = require 'main'

-- Internal helper: Run a single test case
local function runTest(name, filePath)
   local ok, raw = pcall(require, filePath)

   if not ok or not raw then
      iguana.logError("Failed to load test message file: " .. filePath)
      return
   end

   iguana.logInfo("Running test: " .. name)
   
   local passed, err = pcall(function()
         processor.processMessage(raw)
      end)

   if passed then
      iguana.logInfo("Test PASSED: " .. name)
   else
      iguana.logWarning("Test FAILED: " .. name .. " - Error: " .. tostring(err))
   end
end

-- Function: testAll
-- Purpose:
--   Run all defined test cases.
--   Each case is defined by { name, file }, where file is a test Lua module.
function test_runner.testAll()
   local tests = {
      { name = "Valid ORM",     file = "test.orm_valid"     },
      { name = "Missing PID",   file = "test.missing_pid"   },
      { name = "Invalid MSH",   file = "test.invalid_msh"   },
      -- Add more test cases as needed
   }

   for _, test in ipairs(tests) do
      runTest(test.name, test.file)
   end
end

return test_runner