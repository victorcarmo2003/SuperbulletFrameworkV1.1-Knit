-- Shared compile+execute+capture-output logic for run_lua_code, used by both
-- SuperbulletServerLogger/CodeExecutor.lua (server) and
-- SuperbulletClientLogger/ClientCodeExecutor.lua (client). Each side supplies
-- its own loadstringFn (server prefers built-in loadstring, client always
-- uses the custom Loadstring module) and formats the final response in its
-- own external contract shape — this module only owns the part that's
-- identical on both sides.

local LogService = game:GetService("LogService")

local CodeExecutorCore = {}

-- Runs `code` through `loadstringFn`, capturing print() output via LogService
-- during execution.
-- Returns (success, output, executionTimeMs, errorMessage).
function CodeExecutorCore.Run(loadstringFn, code)
	local capturedOutput = {}

	-- Print capture limitation: LogService.MessageOut captures ALL prints during
	-- the execution window, including from other scripts running concurrently.
	-- Acceptable for short, infrequent AI debug commands.
	local logConnection = LogService.MessageOut:Connect(function(message, messageType)
		if messageType == Enum.MessageType.MessageOutput then
			table.insert(capturedOutput, message)
		end
	end)

	local startTime = os.clock()

	local fn, compileError = loadstringFn(code)
	if not fn then
		logConnection:Disconnect()
		return false, nil, 0, "Compile error: " .. tostring(compileError)
	end

	local execSuccess, execResult = pcall(fn)
	local executionTime = math.floor((os.clock() - startTime) * 1000) -- milliseconds

	logConnection:Disconnect()

	if not execSuccess then
		return false, nil, executionTime, tostring(execResult)
	end

	local output = table.concat(capturedOutput, "\n")
	if execResult ~= nil then
		output = (output ~= "" and (output .. "\n") or "") .. tostring(execResult)
	end

	return true, output, executionTime, nil
end

return CodeExecutorCore
