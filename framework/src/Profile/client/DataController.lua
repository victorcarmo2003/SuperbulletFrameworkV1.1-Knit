local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Superbullet = require(ReplicatedStorage.Packages.Superbullet)

local DataController = Superbullet.CreateController({
	Name = "DataController",
	Data = nil,
})

---- Superbullet Services
local ProfileService

local DEFAULT_LOAD_TIMEOUT = 30 -- seconds

-- Updates that arrive before the first GetData response populates
-- DataController.Data get queued here and replayed once it loads, instead of
-- being silently dropped.
local pendingUpdates = {}

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

function DataController:RequestToUpdateData()
	ProfileService.GetData:Fire()
end

function DataController:SuperbulletStart()
	-- Connect listeners BEFORE requesting data, so an UpdateSpecificData fired
	-- by the server right after join is never missed.
	ProfileService.GetData:Connect(function(newData)
		DataController.Data = newData

		if #pendingUpdates > 0 then
			for _, update in ipairs(pendingUpdates) do
				applyUpdate(update.redirectories, update.newValue)
			end
			pendingUpdates = {}
		end
	end)

	ProfileService.UpdateSpecificData:Connect(function(redirectories, newValue)
		if not DataController.Data then
			-- First load hasn't landed yet — queue it instead of dropping it.
			table.insert(pendingUpdates, { redirectories = redirectories, newValue = newValue })
			return
		end

		applyUpdate(redirectories, newValue)
	end)

	DataController:RequestToUpdateData()
	DataController:WaitUntilProfileLoaded()
end

function DataController:SuperbulletInit()
	ProfileService = Superbullet.GetService("ProfileService")
end

return DataController
