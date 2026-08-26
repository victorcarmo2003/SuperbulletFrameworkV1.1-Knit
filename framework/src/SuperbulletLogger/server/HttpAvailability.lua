-- AI NOTE: Checks whether HttpService is enabled and whether the backend is
-- reachable. If HttpService is disabled, notifies players (existing + future)
-- via the httpDisabledEvent RemoteEvent so the client can show a warning UI.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local HttpAvailability = {}

local function isHttpServiceEnabled()
	local success, result = pcall(function()
		-- Errors immediately (before any real network call) if disabled.
		HttpService:GetAsync("http://localhost:1")
	end)

	if not success then
		local errorMsg = tostring(result):lower()
		if errorMsg:find("http requests are not enabled") or errorMsg:find("httpservice is not enabled") then
			return false
		end
	end

	return true
end

-- Checks HttpService availability. If disabled, fires httpDisabledEvent at
-- every current and future player. Returns true if enabled.
function HttpAvailability.CheckAndNotify(httpDisabledEvent)
	local httpEnabled = isHttpServiceEnabled()
	if httpEnabled then
		return true
	end

	warn("[SuperbulletLogger] HttpService is disabled! Superbullet AI debugger requires HttpService to be enabled.")

	Players.PlayerAdded:Connect(function(player)
		task.delay(1, function()
			httpDisabledEvent:FireClient(player)
		end)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		task.delay(1, function()
			httpDisabledEvent:FireClient(player)
		end)
	end

	return false
end

-- Checks if the backend (localhost or cloud) is reachable. A 404 or other
-- HTTP-level error still counts as "reachable" — only connection
-- refused/timeout means the backend process isn't running.
function HttpAvailability.IsBackendReachable(config, getEndpointUrl)
	local url = getEndpointUrl(config, "/health")

	local success, result = pcall(function()
		return HttpService:GetAsync(url)
	end)

	if success then
		return true
	end

	local errorMsg = tostring(result):lower()
	if errorMsg:find("connection refused") or errorMsg:find("connect") or errorMsg:find("timeout") then
		return false
	end

	return true
end

return HttpAvailability
