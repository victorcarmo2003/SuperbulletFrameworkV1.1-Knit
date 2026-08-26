local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Superbullet = require(ReplicatedStorage.Packages.Superbullet)
local Signal = require(ReplicatedStorage.Packages.Signal)

local ProfileService = Superbullet.CreateService({
	Name = "ProfileService",
	Client = {
		GetData = Superbullet.CreateSignal(),

		--[[
			@description Use this for client to reduce network receive data, this updates DataController.Data

			Note: If you use :Connect() and want to retrieve updated data, ensure to add a task.wait()
			at least for the DataController.Data to update.
		]]
		UpdateSpecificData = Superbullet.CreateSignal(),
	},
	Instance = script, -- Automatically initializes Components/Accessor.lua and Components/Mutator.lua

	UpdateSpecificData = Signal.new(),
	Profiles = {}, -- [player] = profile
})

local ActualProfileStore = require(script.Parent:WaitForChild("Externals", 10):WaitForChild("ProfileStore", 10))
local ProfileTemplate = require(ReplicatedStorage.Profile.ProfileTemplate)

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

	-- Handle client data requests
	ProfileService.Client.GetData:Connect(function(player)
		ProfileService:WaitUntilProfileLoaded(player)
		local _, profileData = ProfileService:GetProfile(player)
		ProfileService.Client.GetData:Fire(player, profileData)
	end)
end

function ProfileService:SuperbulletInit()
	PlayerProfileStore = ActualProfileStore.New("OriginalData1", ProfileTemplate)
end

return ProfileService
