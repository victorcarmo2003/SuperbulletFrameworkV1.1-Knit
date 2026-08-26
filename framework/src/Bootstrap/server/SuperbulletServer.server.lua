local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local SuperbulletModule = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Superbullet")
local Superbullet = require(SuperbulletModule)

-- Feature-based layout: Services live under any feature's server/ folder
-- (ServerScriptService.<Feature>.server.<...>), not under one fixed
-- ServerSource.Server root anymore — so this loads every ModuleScript in
-- ServerScriptService whose name ends in "Service". Vendored third-party code
-- (e.g. Profile/server/Externals/ProfileService.lua) is skipped so it isn't
-- accidentally required as if it were a Superbullet Service.
for _, module in pairs(ServerScriptService:GetDescendants()) do
	if module:IsA("ModuleScript") and module.Name:match("Service$") then
		if not module:GetFullName():find("%.Externals%.") then
			local ok, err = pcall(require, module)
			if not ok then
				task.spawn(error, "[Superbullet] Failed to load " .. module:GetFullName() .. ": " .. tostring(err))
			end
		end
	end
end

Superbullet.Start():andThen(
	function()
		print("Superbullet Server initiated.")
		SuperbulletModule:SetAttribute("SuperbulletServer_Initialized",true)
	end
	)
	:catch(warn)
