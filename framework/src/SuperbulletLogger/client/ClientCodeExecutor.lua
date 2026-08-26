-- AI NOTE: Client-side code executor for run_lua_code client context.
-- Runs in client context so LocalPlayer, PlayerGui, and client-only APIs are accessible.
-- Shares its compile/execute/capture core with the server-side CodeExecutor via
-- ReplicatedStorage.SuperbulletLogger.CodeExecutorCore.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CodeExecutorCore =
	require(ReplicatedStorage.SuperbulletLogger.CodeExecutorCore)

local PREFIX = "[SuperbulletCodeExecutor]"

-- Client always uses custom Loadstring module (built-in loadstring not available for clients)
local loadstringFn
local success, customLoadstring = pcall(function()
	return require(ReplicatedStorage.SuperbulletLogger.Loadstring)
end)
if success then
	loadstringFn = customLoadstring
else
	warn(PREFIX, "Client: Loadstring module not found at ReplicatedStorage.SuperbulletLogger.Loadstring")
	warn(PREFIX, "Client code execution will not be available")
end

local ClientCodeExecutor = {}

function ClientCodeExecutor.execute(code)
	if not loadstringFn then
		return {
			success = false,
			error = "Loadstring module not available. Add Loadstring to ReplicatedStorage.SuperbulletLogger.",
		}
	end

	local success, output, executionTime, errorMessage = CodeExecutorCore.Run(loadstringFn, code)

	if not success then
		return {
			success = false,
			error = errorMessage,
		}
	end

	return {
		success = true,
		output = output,
		executionTime = executionTime,
	}
end

return ClientCodeExecutor
