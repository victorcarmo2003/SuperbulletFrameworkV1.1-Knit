-- AI NOTE: Executes Lua code received from run_lua_code WebSocket messages.
-- Uses loadstring() + pcall() for safe execution with print output capture via LogService.
-- Runs in server context (ServerScriptService) so loadstring and server APIs are available.
-- Shares its compile/execute/capture core with the client-side ClientCodeExecutor
-- via ReplicatedStorage.SuperbulletLogger.CodeExecutorCore.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CodeExecutorCore =
	require(ReplicatedStorage.SuperbulletLogger.CodeExecutorCore)

local PREFIX = "[SuperbulletCodeExecutor]"

-- Check if Roblox's built-in loadstring is available (requires ServerScriptService.LoadStringEnabled = true)
local builtinLoadstringEnabled = pcall(function()
	local fn = loadstring("return true")
	return fn and fn()
end)

-- Determine which loadstring to use (server prioritizes built-in, falls back to custom)
local loadstringFn
if builtinLoadstringEnabled then
	loadstringFn = loadstring
else
	-- Fallback to custom Loadstring module
	local success, customLoadstring = pcall(function()
		return require(ReplicatedStorage.Packages.Loadstring)
	end)
	if success then
		loadstringFn = customLoadstring
	else
		warn(PREFIX, "loadstring() is not available and custom Loadstring module not found!")
		warn(PREFIX, "To enable code execution, either:")
		warn(PREFIX, "  1. Set ServerScriptService.LoadStringEnabled = true in Studio (disable in production)")
		warn(PREFIX, "  2. Add Loadstring module to ReplicatedStorage.Packages")
	end
end

local CodeExecutor = {}

-- Check if code will end the playtest (needs deferred execution)
local function isEndTestCode(code)
	return code:find("StudioTestService") and code:find("EndTest")
end

function CodeExecutor.execute(requestId, code)
	if not loadstringFn then
		return {
			success = false,
			error = "loadstring() is not available. Enable ServerScriptService.LoadStringEnabled or add Loadstring module.",
		}
	end

	-- Special case: EndTest must be deferred so we can send response first
	if isEndTestCode(code) then
		local fn, compileError = loadstringFn(code)
		if not fn then
			return {
				success = false,
				error = "Compile error: " .. tostring(compileError),
			}
		end

		-- Delay execution so response can be sent first
		task.delay(0.5, function()
			pcall(fn)
		end)

		return {
			success = true,
			data = {
				output = "Ending playtest...",
				executionTime = 0,
			},
		}
	end

	local success, output, executionTime, errorMessage = CodeExecutorCore.Run(loadstringFn, code)

	if not success then
		warn(PREFIX, errorMessage)
		return {
			success = false,
			error = errorMessage,
		}
	end

	return {
		success = true,
		data = {
			output = output,
			executionTime = executionTime,
		},
	}
end

return CodeExecutor
