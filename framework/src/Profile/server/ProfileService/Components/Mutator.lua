-- ProfileService Mutator — write access to profile data.
-- Communicates only with the parent system (ProfileService/init.lua), per
-- .claude/rules/knit-architecture.md. Never require Accessor.lua directly —
-- read the current profile through the parent's ProfileService:GetProfile().

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Superbullet = require(ReplicatedStorage.Packages.Superbullet)

local module = {}

local ProfileService -- set in Init(), the parent ProfileService

function module.ChangeData(player, redirectories, newValue)
	local _, profileData = ProfileService:GetProfile(player)

	if not profileData then
		warn("[ProfileService.Mutator] Profile data not found for player: " .. (player.Name or "Unknown"))
		return
	end

	local directData = profileData

	-- Navigate through the redirectories path
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

	-- Set the new value
	directData[redirectories[#redirectories]] = newValue

	-- Fire update signals
	ProfileService.Client.UpdateSpecificData:Fire(player, redirectories, newValue)
	ProfileService.UpdateSpecificData:Fire(player, redirectories, newValue)
end

function module.Init()
	ProfileService = Superbullet.GetService("ProfileService")
end

return module
