local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SuperbulletModule = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Superbullet")
local Superbullet = require(SuperbulletModule)

-- Feature-based layout: this script lives at StarterPlayerScripts.Bootstrap
-- (one folder among several feature folders — Bootstrap, Profile,
-- SuperbulletLogger, etc. — that are siblings directly under
-- StarterPlayerScripts, not nested under Bootstrap). Controllers can live in
-- any feature's client/ folder, so this scans the whole PlayerScripts tree
-- (StarterPlayerScripts cloned into the local player) instead of just its
-- own Bootstrap folder.
local playerScripts = Players.LocalPlayer:WaitForChild("PlayerScripts")
for _, module in pairs(playerScripts:GetDescendants()) do
	if module:IsA("ModuleScript") and (module.Name:match("Controller$") or module.Name:match("Behavior$")) then
		local ok, err = pcall(require, module)
		if not ok then
			task.spawn(error, "[Superbullet] Failed to load " .. module:GetFullName() .. ": " .. tostring(err))
		end
	end
end

Superbullet.Start()
	:andThen(function()
	print("Superbullet Client initiated.")
	SuperbulletModule:SetAttribute("SuperbulletClient_Initialized",true)
end
)
	:catch(warn)
