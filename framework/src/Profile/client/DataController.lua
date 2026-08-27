local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Superbullet = require(ReplicatedStorage.Packages.Superbullet)
local Net = require(ReplicatedStorage.Profile.Net)

local DataController = Superbullet.CreateController({
	Name = "DataController",
	Data = nil,
})

local DEFAULT_LOAD_TIMEOUT = 30 -- seconds

local function applyUpdate(redirectories, newValue)
	local directData = DataController.Data

	for i = 1, #redirectories do
		if not directData[redirectories[i]] and i ~= #redirectories then
			local redirectoriesPath = "profileData"
			for j = 1, i do
				redirectoriesPath = redirectoriesPath .. "." .. redirectories[j]
			end
			error(
				"'"
					.. redirectoriesPath
					.. "' table does not exist. ALWAYS PREVENT THIS BY MAKING TABLES INSIDE PROFILETEMPLATE."
			)
		end

		if i ~= #redirectories then
			directData = directData[redirectories[i]]
		end
	end

	directData[redirectories[#redirectories]] = newValue
end

function DataController:GetPlayerData()
	return DataController.Data
end

--- Waits until player data has loaded, or gives up after `timeoutSeconds`
--- (default 30s) so a profile that never arrives doesn't hang the caller forever.
--- Returns true if data loaded, false if it timed out.
function DataController:WaitUntilProfileLoaded(timeoutSeconds)
	local timeout = timeoutSeconds or DEFAULT_LOAD_TIMEOUT
	local startTime = os.clock()

	repeat
		task.wait()

		if os.clock() - startTime >= timeout then
			warn("[DataController] Timed out after " .. timeout .. "s waiting for profile data to load")
			return false
		end
	until DataController.Data

	return true
end

--- Explicit re-sync pull. Not the normal load path anymore (that's automatic
--- via Net.Fields:onAdded/catchup below) — useful to force a refresh on demand.
function DataController:RequestToUpdateData()
	local ok, data = Net.RequestProfile:request(nil)
	if ok then
		DataController.Data = data
	end
	return ok
end

function DataController:SuperbulletStart()
	-- audience() on the server already restricts this Set to just this
	-- player's own record, so there is no other id to filter out here.
	-- Lync's own catchup covers late join / becoming ready after load, so
	-- there's no manual pending-updates queue needed anymore.
	Net.Fields:onAdded(function(_, record)
		DataController.Data = record.profile
	end)

	Net.Fields:onChanged(function(_, record)
		DataController.Data = record.profile
	end)

	Net.KeyChanged:onClient(function(update)
		if DataController.Data then
			applyUpdate(update.path, update.value)
		end
	end)

	DataController:WaitUntilProfileLoaded()
end

return DataController