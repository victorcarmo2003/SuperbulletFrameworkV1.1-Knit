local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProgressBar = require(script.Parent.Parent.Elements.ProgressBar)
local vide = require(ReplicatedStorage.Packages.vide)
local source = vide.source

return function(target: Instance)
	local progress = source(0)

	local thread = task.spawn(function()
		while task.wait(0.05) do
			local value = progress() + 0.01
			if value > 1 then
				value = 0
			end
			progress(value)
		end
	end)

	local dismount = ProgressBar({
		Parent = target,
		Progress = progress,
	})

	return function()
		dismount()
		task.cancel(thread)
	end
end
