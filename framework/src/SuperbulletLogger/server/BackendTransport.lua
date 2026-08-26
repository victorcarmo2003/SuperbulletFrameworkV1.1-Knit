-- AI NOTE: Sends batched logs and playtest lifecycle notifications to the
-- Superbullet backend (localhost or cloud, per RemoteConfig).

local HttpService = game:GetService("HttpService")

local RemoteConfig = require(script.Parent.RemoteConfig)

local BackendTransport = {}

local function getTimestampMs()
	return DateTime.now().UnixTimestampMillis
end

function BackendTransport.SendLogs(config, logs)
	if #logs == 0 then
		return
	end

	local url = RemoteConfig.GetEndpointUrl(config, "/playtest/logs")
	local body = HttpService:JSONEncode({
		token = config.mode == "cloud" and config.cloudToken or nil,
		timestamp = getTimestampMs(),
		logs = logs,
	})

	local success, result = pcall(function()
		return HttpService:PostAsync(url, body, Enum.HttpContentType.ApplicationJson)
	end)

	if not success then
		warn("[SuperbulletLogger] Failed to send logs:", result)
	end
end

function BackendTransport.NotifyPlaytestStart(config)
	local url = RemoteConfig.GetEndpointUrl(config, "/playtest/start")
	local body = HttpService:JSONEncode({
		token = config.mode == "cloud" and config.cloudToken or nil,
		timestamp = getTimestampMs(),
	})

	pcall(function()
		HttpService:PostAsync(url, body, Enum.HttpContentType.ApplicationJson)
	end)
end

function BackendTransport.NotifyPlaytestStop(config)
	local url = RemoteConfig.GetEndpointUrl(config, "/playtest/stop")
	local body = HttpService:JSONEncode({
		token = config.mode == "cloud" and config.cloudToken or nil,
		timestamp = getTimestampMs(),
	})

	pcall(function()
		HttpService:PostAsync(url, body, Enum.HttpContentType.ApplicationJson)
	end)
end

return BackendTransport
