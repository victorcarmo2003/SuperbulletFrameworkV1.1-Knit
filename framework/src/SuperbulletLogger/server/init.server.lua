-- SuperbulletServerLogger.server.lua
-- Collects logs from server and client, batches them, sends to frontend.
-- Orchestrates RemoteConfig (backend URLs), HttpAvailability (HttpService
-- checks), LogBuffer (buffering), BackendTransport (sending), WebSocketClient
-- (run_lua_code push), CodeExecutor/ClientQueryRouter (code execution).
-- NOTE: Only runs in Roblox Studio, not in production.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LogService = game:GetService("LogService")
local RunService = game:GetService("RunService")

-- Only run in Studio (useless in production)
if not RunService:IsStudio() then
	return
end

local RemoteConfig = require(script.RemoteConfig)
local HttpAvailability = require(script.HttpAvailability)
local LogBuffer = require(script.LogBuffer)
local BackendTransport = require(script.BackendTransport)
local WebSocketClient = require(script.WebSocketClient)
local CodeExecutor = require(script.CodeExecutor)
local ClientQueryRouter = require(script.ClientQueryRouter)
local LogLevel = require(ReplicatedStorage.SuperbulletLogger.LogLevel)

local BATCH_INTERVAL = 1 -- seconds

local CODE_EXECUTOR_PREFIX = "[SuperbulletCodeExecutor]"

-- Create RemoteEvent for client logs
local clientLogEvent = Instance.new("RemoteEvent")
clientLogEvent.Name = "SuperbulletClientLog"
clientLogEvent.Parent = ReplicatedStorage

-- Create RemoteEvent to notify client if HttpService is disabled
local httpDisabledEvent = Instance.new("RemoteEvent")
httpDisabledEvent.Name = "SuperbulletHttpDisabled"
httpDisabledEvent.Parent = ReplicatedStorage

-- Create RemoteFunction for client-side code queries (path expression evaluator)
local clientQueryFunction = Instance.new("RemoteFunction")
clientQueryFunction.Name = "SuperbulletClientQuery"
clientQueryFunction.Parent = ReplicatedStorage

local httpEnabled = HttpAvailability.CheckAndNotify(httpDisabledEvent)
if not httpEnabled then
	-- Client already shows a warning UI via httpDisabledEvent; nothing more to do.
	return
end

local config = RemoteConfig.GetConfig()
local buffer = LogBuffer.new()

local backendReachable = HttpAvailability.IsBackendReachable(config, RemoteConfig.GetEndpointUrl)
if not backendReachable then
	warn(CODE_EXECUTOR_PREFIX, "Backend not reachable at", config.mode == "cloud" and "cloud backend" or ("localhost:" .. config.port))
	warn(CODE_EXECUTOR_PREFIX, "Code execution features will not be available until the backend is running")
end

-- Listen for server-side log messages
LogService.MessageOut:Connect(function(message, messageType)
	local level = LogLevel.FromMessageType(messageType)
	buffer:Add("server", level, message)
end)

-- Listen for client logs via RemoteEvent
clientLogEvent.OnServerEvent:Connect(function(player, logData)
	if type(logData) ~= "table" then
		return
	end
	if type(logData.level) ~= "string" then
		return
	end
	if type(logData.message) ~= "string" then
		return
	end

	local sanitizedMessage = logData.message:sub(1, 1000) -- Limit message length
	buffer:Add("client", logData.level, sanitizedMessage, logData.traceback)
end)

-- Batch send loop
task.spawn(function()
	BackendTransport.NotifyPlaytestStart(config)

	while true do
		task.wait(BATCH_INTERVAL)

		if not buffer:IsEmpty() then
			local logsToSend = buffer:DrainUpTo(LogBuffer.MAX_BATCH_SIZE)
			BackendTransport.SendLogs(config, logsToSend)
		end
	end
end)

-- Detect execution context from a run_lua_code message.
-- Returns ("client", strippedCode) or ("server", originalCode).
local function detectContext(message)
	-- 1. Explicit context field from backend
	if message.context == "client" then
		return "client", message.code
	end

	-- 2. --@client prefix in code string
	local code = message.code or ""
	local stripped = code:match("^%-%-@client%s*(.*)")
	if stripped then
		return "client", stripped
	end

	-- 3. Default: server
	return "server", code
end

-- Client query router (initialized once, used by WebSocket handler)
local clientRouter = ClientQueryRouter.new(clientQueryFunction)

-- WebSocket connection for run_lua_code (both localhost and cloud modes)
-- Connects to the backend so it can push run_lua_code requests directly
-- to this game instance instead of routing through the plugin's HTTP polling.
-- Cloud mode requires cloudToken, localhost mode connects to ws://localhost:port/ws
local canConnectWebSocket = (config.mode == "cloud" and config.cloudToken) or (config.mode == "localhost")

if canConnectWebSocket then
	if not backendReachable then
		warn(CODE_EXECUTOR_PREFIX, "Skipping WebSocket connection - backend not reachable")
	else
		local wsClient = WebSocketClient.new(config)

		wsClient:setMessageHandler(function(message)
			if message.type == "run_lua_code" then
				-- Wrap in task.spawn so pings are still processed during execution
				task.spawn(function()
					local context, code = detectContext(message)
					local result

					if context == "client" then
						result = clientRouter:execute(code, message.requestId)
					else
						result = CodeExecutor.execute(message.requestId, code)
					end

					wsClient:sendResponse({
						type = "run_lua_code_response",
						requestId = message.requestId,
						result = result,
						timestamp = DateTime.now().UnixTimestampMillis,
					})
				end)
			end
		end)

		local connected = wsClient:connect()
		if not connected then
			warn(CODE_EXECUTOR_PREFIX, "Failed to initiate WebSocket connection")
		end

		-- Disconnect on game close (registered before log flush BindToClose so it runs first)
		game:BindToClose(function()
			wsClient:disconnect()
		end)
	end
end

-- Notify playtest stopped on game close
game:BindToClose(function()
	-- Send remaining logs in batches to avoid timeout
	while not buffer:IsEmpty() do
		local logsToSend = buffer:DrainUpTo(LogBuffer.MAX_BATCH_SIZE)
		BackendTransport.SendLogs(config, logsToSend)
	end

	BackendTransport.NotifyPlaytestStop(config)
end)

print("[SuperbulletLogger] Server logger initialized (Studio only)")
