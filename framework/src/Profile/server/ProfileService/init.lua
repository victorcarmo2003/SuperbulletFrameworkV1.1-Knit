local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Superbullet = require(ReplicatedStorage.Packages.Superbullet)
local Signal = require(ReplicatedStorage.Packages.Signal)

local ProfileService = Superbullet.CreateService({
	Name = "ProfileService",
	Instance = script, -- Automatically initializes Components/Accessor.lua and Components/Mutator.lua

	UpdateSpecificData = Signal.new(),
	Profiles = {}, -- [player] = profile
})

local ActualProfileStore = require(script.Parent:WaitForChild("Externals", 10):WaitForChild("ProfileStore", 10))
local ProfileTemplate = require(ReplicatedStorage.Profile.ProfileTemplate)
local Net = require(ReplicatedStorage.Profile.Net)

local PlayerProfileStore

local PROFILE_LOAD_TIMEOUT = 30 -- seconds

local function DataSuccessfullyLoaded(player)
	-- Called when a profile is successfully loaded
	-- Add any post-load logic here
end

local function HandlePlayerAdded(player)
	local profile = PlayerProfileStore:StartSessionAsync("Player_" .. player.UserId)

	if profile ~= nil then
		profile:AddUserId(player.UserId) -- GDPR compliance
		profile:Reconcile() -- Fill in missing variables from ProfileTemplate

		-- Add MetaData for backwards compatibility
		if not profile.MetaData then
			profile.MetaData = {
				ProfileCreateTime = profile.FirstSessionTime,
				SessionLoadCount = profile.SessionLoadCount,
				ActiveSession = profile.Session,
			}
		end

		profile.OnSessionEnd:Connect(function()
			ProfileService.Profiles[player] = nil
			-- The profile could've been loaded on another Roblox server
			player:Kick()
		end)

		if player:IsDescendantOf(Players) then
			ProfileService.Profiles[player] = profile

			Net.Fields:add(player.UserId, { owner = player.UserId, profile = table.clone(profile.Data) })
			Net.Fields:audience(player.UserId, player)

			DataSuccessfullyLoaded(player)
		else
			-- Player left before the profile loaded
			profile:EndSession()
		end
	else
		-- The profile couldn't be loaded possibly due to other
		-- Roblox servers trying to load this profile at the same time
		player:Kick()
	end
end

local function HandlePlayerRemoving(player)
	local profile = ProfileService.Profiles[player]
	if profile ~= nil then
		Net.Fields:remove(player.UserId)
		profile:EndSession()
	end
end

--- Waits until the player's profile has loaded, or gives up after `timeoutSeconds`
--- (default 30s) so a session that never loads doesn't hang the caller forever.
--- Returns true if the profile loaded, false if it timed out or the player left.
function ProfileService:WaitUntilProfileLoaded(player, timeoutSeconds)
	local timeout = timeoutSeconds or PROFILE_LOAD_TIMEOUT
	local elapsed = 0

	repeat
		task.wait(2)
		elapsed += 2

		if RunService:IsStudio() then
			print("Waiting for profile to load for " .. player.Name .. "...")
		end

		if elapsed >= timeout then
			warn(
				string.format(
					"[ProfileService] Timed out after %ds waiting for %s's profile to load",
					timeout,
					player.Name
				)
			)
			return false
		end
	until ProfileService.Profiles[player] or not player:IsDescendantOf(Players)

	return ProfileService.Profiles[player] ~= nil
end

--- Delegates to Components/Accessor.lua. Kept on the service itself so existing
--- callers of ProfileService:GetProfile(player) keep working unchanged.
function ProfileService:GetProfile(player)
	return ProfileService.Accessor.GetProfile(player)
end

--- Delegates to Components/Mutator.lua. Kept on the service itself so existing
--- callers of ProfileService:ChangeData(...) keep working unchanged.
function ProfileService:ChangeData(player, redirectories, newValue)
	ProfileService.Mutator.ChangeData(player, redirectories, newValue)
end

function ProfileService.Client:GetOtherPlayer_ProfileData(player, otherPlayer)
	return ProfileService.Accessor.GetOtherPlayer_ProfileData(otherPlayer)
end

function ProfileService.Client:GetProfileAge(player)
	return ProfileService.Accessor.GetProfileAge(player)
end

function ProfileService:SuperbulletStart()
	-- Handle existing players
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(HandlePlayerAdded, player)
	end

	-- Connect player events
	Players.PlayerAdded:Connect(HandlePlayerAdded)
	Players.PlayerRemoving:Connect(HandlePlayerRemoving)

	-- Handle explicit client re-sync requests (the normal load path is
	-- Net.Fields:add/audience above — this is only for an on-demand pull).
	Net.RequestProfile:onServer(function(path, player)
		-- GetProfile/Accessor.GetProfile already waits for the profile to load
		-- if it hasn't yet — no need to wait a second time here.
		local _, data = ProfileService:GetProfile(player)
		if not data then
			return nil
		end
		return ProfileService.Accessor.GetDataAtPath(data, path)
	end)
end

function ProfileService:SuperbulletInit()
	PlayerProfileStore = ActualProfileStore.New("OriginalData1", ProfileTemplate)
end

return ProfileService
