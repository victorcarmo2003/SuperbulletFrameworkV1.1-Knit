local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Component = require(ReplicatedStorage.Packages.Component)
local PromptMixin = require(ReplicatedStorage.Mixins.PromptMixin)

local PickupBehavior = Component.new({
	Tag = "Pickup",
})

function PickupBehavior:Construct()
	-- No yield here — same rule as SuperbulletInit/Construct in Knit.
	self.Collected = false
end

function PickupBehavior:Start()
	local prompt = PromptMixin.Attach(self, { ActionText = "Pick Up" })

	self._triggeredConn = prompt.Triggered:Connect(function(player)
		if self.Collected then
			return
		end
		self.Collected = true
		print(("[PickupBehavior] %s collected by %s"):format(self.Instance.Name, player.Name))
	end)
end

function PickupBehavior:Stop()
	if self._triggeredConn then
		self._triggeredConn:Disconnect()
		self._triggeredConn = nil
	end
	PromptMixin.Detach(self)
end

return PickupBehavior
