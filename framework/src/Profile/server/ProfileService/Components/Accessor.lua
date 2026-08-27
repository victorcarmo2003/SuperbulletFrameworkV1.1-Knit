-- ProfileService Accessor — read-only profile access.
-- Communicates only with the parent system (ProfileService/init.lua), per
-- .claude/rules/knit-architecture.md. Never require Mutator.lua directly.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Superbullet = require(ReplicatedStorage.Packages.Superbullet)

local module = {}

local ProfileService -- set in Init(), the parent ProfileService

function module.GetProfile(player)
	if player == nil then
		warn("[ProfileService.Accessor] Player instance is nil when getting profile")
		return nil
	end

	if not ProfileService.Profiles[player] then
		ProfileService:WaitUntilProfileLoaded(player)
	end

	local profile = ProfileService.Profiles[player]
	return profile, profile and profile.Data
end

function module.GetOtherPlayer_ProfileData(otherPlayer)
	local _, profileData = module.GetProfile(otherPlayer)
	return profileData
end

function module.GetProfileAge(player)
	local profile = module.GetProfile(player)
	if not profile then
		return 0
	end

	return os.time() - profile.FirstSessionTime
end

--- Read-only walk of a profile data table by path, e.g. {"Settings", "MusicVolume"}.
--- `path == nil` returns the whole table. Returns nil if any step along the way is absent.
function module.GetDataAtPath(data, path)
	if path == nil then
		return data
	end

	local current = data
	for i = 1, #path do
		if current == nil then
			return nil
		end
		current = current[path[i]]
	end

	return current
end

function module.Init()
	ProfileService = Superbullet.GetService("ProfileService")
end

return module
