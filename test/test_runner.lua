-- ====================================================================
-- test_runner.lua
-- Author: Conor Steward
-- Date Created: 6/2/25
--
-- Purpose:
-- Executes predefined test cases using embedded HL7 test message files.
-- Validates the HL7 ingestion pipeline from parsing through ACK/NACK generation.
--
-- Usage:
--   From the Iguana Translator development panel, call:
--     test_runner.testAll()
--
-- Notes:
-- - Test messages are stored in .lua files and return raw HL7 strings.
-- - Test results are logged to Iguana's log tab.
-- - Requires the main() function to accept raw HL7 input for testability.
-- ====================================================================

local test_runner = {}

-- Function: testAll
-- Purpose:
--   Runs a set of test cases defined in testRunner.tests.
--   Loads HL7 message content from .lua test files.
--   Passes each message to main() and captures success/failure.
--
-- Input: None (uses inline table of test cases)
-- Output: None (writes results to Iguana logs)
function test_runner.testAll()
   local tests = {
      { name = "Valid ORM",     file = "test.orm_valid"     },
      { name = "Missing PID",   file = "test.missing_pid"   },
      { name = "Invalid MSH",   file = "test.invalid_msh"   },
   }

   for _, test in ipairs(tests) do
      -- Load HL7 message from Lua module file
      local ok, raw = pcall(require, test.file)

      if ok and raw then
         iguana.logInfo("Running test case: " .. test.name)

         -- Execute test safely
         local passed, err = pcall(function()
            main(raw)
         end)

         if passed then
            iguana.logInfo("Test PASSED: " .. test.name)
         else
            iguana.logWarning("Test FAILED: " .. test.name .. " - Error: " .. tostring(err))
         end
      else
         iguana.logError("Unable to load test file: " .. test.file)
      end
   end
end

return test_runner
