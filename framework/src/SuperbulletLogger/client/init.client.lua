-- SuperbulletClientLogger.client.lua
-- Captures client-side logs and sends them to server via RemoteEvent.
-- Orchestrates HttpDisabledUI (warning screen), ClientCodeExecutor (run_lua_code).
-- NOTE: Only runs in Roblox Studio, not in production.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LogService = game:GetService("LogService")
local RunService = game:GetService("RunService")

-- Only run in Studio (useless in production)
if not RunService:IsStudio() then
	return
end

local HttpDisabledUI = require(script.HttpDisabledUI)
local ClientCodeExecutor = require(script.ClientCodeExecutor)
local LogLevel = require(ReplicatedStorage.SuperbulletLogger.LogLevel)

-- Listen for HttpService disabled notification from server
local httpDisabledEvent = ReplicatedStorage:WaitForChild("SuperbulletHttpDisabled", 5)
if httpDisabledEvent then
	httpDisabledEvent.OnClientEvent:Connect(function()
		HttpDisabledUI.Create()
	end)
end

-- Wait for RemoteEvent (created by server logger)
local clientLogEvent = ReplicatedStorage:WaitForChild("SuperbulletClientLog", 10)
if not clientLogEvent then
	-- If we can't find it and httpDisabledEvent was fired, UI is already showing
	-- Otherwise warn about missing event
	if not httpDisabledEvent then
		warn("[SuperbulletLogger] Could not find client log event")
	end
	return
end

-- Rate limiting
local LOG_RATE_LIMIT = 10 -- max logs per second
local logCount = 0
local lastResetTime = tick()

local function canSendLog()
	local now = tick()
	if now - lastResetTime >= 1 then
		logCount = 0
		lastResetTime = now
	end

	if logCount >= LOG_RATE_LIMIT then
		return false
	end

	logCount = logCount + 1
	return true
end

-- Send log to server
local function sendLog(level, message, traceback)
	if not canSendLog() then
		return
	end

	clientLogEvent:FireServer({
		level = level,
		message = message,
		traceback = traceback,
	})
end

-- Listen for client-side log messages
LogService.MessageOut:Connect(function(message, messageType)
	local level = LogLevel.FromMessageType(messageType)
	sendLog(level, message)
end)

-- Listen for client query requests via RemoteFunction
local clientQueryFunction = ReplicatedStorage:WaitForChild("SuperbulletClientQuery", 10)
if clientQueryFunction then
	clientQueryFunction.OnClientInvoke = function(payload)
		if type(payload) ~= "table" or type(payload.code) ~= "string" then
			return { success = false, error = "Invalid client query payload" }
		end

		return ClientCodeExecutor.execute(payload.code)
	end
end

print("[SuperbulletLogger] Client logger initialized (Studio only)")
