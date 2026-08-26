local ReplicatedStorage = game:GetService("ReplicatedStorage")
local vide = require(ReplicatedStorage.Packages.vide)
local create = vide.create

export type Props = {
	Parent: Instance,
	Progress: () -> number, -- 0 a 1
}

return function(props: Props): () -> ()
	return vide.mount(function()
		return create "Frame" {
			Name = "ProgressBar",
			Parent = props.Parent,
			Size = UDim2.fromOffset(200, 24),
			BackgroundColor3 = Color3.fromRGB(40, 40, 40),
			BorderSizePixel = 0,

			create "Frame" {
				Name = "Fill",
				BackgroundColor3 = Color3.fromRGB(80, 170, 255),
				BorderSizePixel = 0,
				Size = function()
					return UDim2.fromScale(math.clamp(props.Progress(), 0, 1), 1)
				end,
			},
		}
	end)
end
