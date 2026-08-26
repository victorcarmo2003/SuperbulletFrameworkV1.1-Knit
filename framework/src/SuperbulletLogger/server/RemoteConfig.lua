-- AI NOTE: Reads playtest connection config and builds backend URLs.
-- Same config shape used everywhere in this logger: {mode, port, cloudToken}.

local ServerStorage = game:GetService("ServerStorage")

local CLOUD_BACKEND_URL = "https://superbullet-backend-3948693.superbulletstudios.com"

local RemoteConfig = {}

-- Reads configuration from ServerStorage.Superbullet.Superbullet_Server.
-- Falls back to localhost:13528 if the config folder/values aren't set up.
function RemoteConfig.GetConfig()
	local superbulletFolder = ServerStorage:FindFirstChild("Superbullet")
	if not superbulletFolder then
		return { mode = "localhost", port = 13528 }
	end

	local configFolder = superbulletFolder:FindFirstChild("Superbullet_Server")
	if not configFolder then
		return { mode = "localhost", port = 13528 }
	end

	local modeValue = configFolder:FindFirstChild("ConnectionMode")
	local portValue = configFolder:FindFirstChild("Port")
	local tokenValue = configFolder:FindFirstChild("CloudToken")

	return {
		mode = modeValue and modeValue.Value or "localhost",
		port = portValue and portValue.Value or 13528,
		cloudToken = tokenValue and tokenValue.Value or nil,
	}
end

-- Builds a full HTTP endpoint URL for the given path, honoring cloud vs
-- localhost mode (cloud mode appends ?token=).
function RemoteConfig.GetEndpointUrl(config, endpoint)
	if config.mode == "cloud" and config.cloudToken then
		return CLOUD_BACKEND_URL .. "/api/superbullet" .. endpoint .. "?token=" .. config.cloudToken
	else
		return string.format("http://localhost:%d%s", config.port, endpoint)
	end
end

return RemoteConfig
