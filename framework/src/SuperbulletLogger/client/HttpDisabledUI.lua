-- AI NOTE: Builds the "HttpService is disabled" warning screen shown to the
-- local player when the server logger detects HttpService is off. Pure UI —
-- no logging/network logic here, see init.client.lua for wiring.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local HttpDisabledUI = {}

function HttpDisabledUI.Create()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	-- Create ScreenGui (DisplayOrder high, ResetOnSpawn false, IgnoreGuiInset true)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "SuperbulletHttpWarning"
	screenGui.DisplayOrder = 999999
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = playerGui

	-- Semi-transparent dark overlay
	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.Position = UDim2.new(0, 0, 0, 0)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.4
	overlay.BorderSizePixel = 0
	overlay.Parent = screenGui

	-- Main warning container
	local container = Instance.new("Frame")
	container.Name = "Container"
	container.Size = UDim2.new(0, 500, 0, 400)
	container.Position = UDim2.new(0.5, -250, 0.5, -200)
	container.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	container.BorderSizePixel = 0
	container.Parent = screenGui

	-- Container corner rounding
	local containerCorner = Instance.new("UICorner")
	containerCorner.CornerRadius = UDim.new(0, 12)
	containerCorner.Parent = container

	-- Orange/yellow accent bar at top
	local accentBar = Instance.new("Frame")
	accentBar.Name = "AccentBar"
	accentBar.Size = UDim2.new(1, 0, 0, 4)
	accentBar.Position = UDim2.new(0, 0, 0, 0)
	accentBar.BackgroundColor3 = Color3.fromRGB(255, 170, 50)
	accentBar.BorderSizePixel = 0
	accentBar.Parent = container

	-- Warning icon (using text emoji as fallback)
	local iconLabel = Instance.new("TextLabel")
	iconLabel.Name = "Icon"
	iconLabel.Size = UDim2.new(0, 60, 0, 60)
	iconLabel.Position = UDim2.new(0.5, -30, 0, 20)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Text = "⚠️"
	iconLabel.TextSize = 48
	iconLabel.Font = Enum.Font.GothamBold
	iconLabel.TextColor3 = Color3.fromRGB(255, 170, 50)
	iconLabel.Parent = container

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -40, 0, 30)
	title.Position = UDim2.new(0, 20, 0, 85)
	title.BackgroundTransparency = 1
	title.Text = "HttpService is Disabled"
	title.TextSize = 24
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.Parent = container

	-- Subtitle
	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.Size = UDim2.new(1, -40, 0, 20)
	subtitle.Position = UDim2.new(0, 20, 0, 118)
	subtitle.BackgroundTransparency = 1
	subtitle.Text = "Superbullet AI Debugger requires HttpService to be enabled"
	subtitle.TextSize = 14
	subtitle.Font = Enum.Font.Gotham
	subtitle.TextColor3 = Color3.fromRGB(180, 180, 180)
	subtitle.Parent = container

	-- Steps container
	local stepsContainer = Instance.new("Frame")
	stepsContainer.Name = "StepsContainer"
	stepsContainer.Size = UDim2.new(1, -40, 0, 160)
	stepsContainer.Position = UDim2.new(0, 20, 0, 150)
	stepsContainer.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
	stepsContainer.BorderSizePixel = 0
	stepsContainer.Parent = container

	local stepsCorner = Instance.new("UICorner")
	stepsCorner.CornerRadius = UDim.new(0, 8)
	stepsCorner.Parent = stepsContainer

	-- Steps header
	local stepsHeader = Instance.new("TextLabel")
	stepsHeader.Name = "StepsHeader"
	stepsHeader.Size = UDim2.new(1, -20, 0, 25)
	stepsHeader.Position = UDim2.new(0, 10, 0, 10)
	stepsHeader.BackgroundTransparency = 1
	stepsHeader.Text = "How to Enable HttpService:"
	stepsHeader.TextSize = 14
	stepsHeader.Font = Enum.Font.GothamBold
	stepsHeader.TextColor3 = Color3.fromRGB(255, 170, 50)
	stepsHeader.TextXAlignment = Enum.TextXAlignment.Left
	stepsHeader.Parent = stepsContainer

	-- Steps text
	local steps = {
		"1. Stop the playtest (click Stop or press Shift+F5)",
		"2. Go to File > Game Settings",
		"3. Navigate to the 'Security' tab",
		"4. Enable 'Allow HTTP Requests'",
		"5. Click 'Save' and restart the playtest",
	}

	for i, step in ipairs(steps) do
		local stepLabel = Instance.new("TextLabel")
		stepLabel.Name = "Step" .. i
		stepLabel.Size = UDim2.new(1, -20, 0, 22)
		stepLabel.Position = UDim2.new(0, 10, 0, 30 + (i - 1) * 24)
		stepLabel.BackgroundTransparency = 1
		stepLabel.Text = step
		stepLabel.TextSize = 13
		stepLabel.Font = Enum.Font.Gotham
		stepLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
		stepLabel.TextXAlignment = Enum.TextXAlignment.Left
		stepLabel.TextWrapped = true
		stepLabel.Parent = stepsContainer
	end

	-- Video tutorial section
	local videoLabel = Instance.new("TextLabel")
	videoLabel.Name = "VideoLabel"
	videoLabel.Size = UDim2.new(0, 120, 0, 20)
	videoLabel.Position = UDim2.new(0, 20, 0, 320)
	videoLabel.BackgroundTransparency = 1
	videoLabel.Text = "Video Tutorial:"
	videoLabel.TextSize = 12
	videoLabel.Font = Enum.Font.GothamMedium
	videoLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	videoLabel.TextXAlignment = Enum.TextXAlignment.Left
	videoLabel.Parent = container

	-- Video URL TextBox (non-editable, copyable)
	local videoUrlBox = Instance.new("TextBox")
	videoUrlBox.Name = "VideoUrlBox"
	videoUrlBox.Size = UDim2.new(1, -160, 0, 24)
	videoUrlBox.Position = UDim2.new(0, 140, 0, 318)
	videoUrlBox.BackgroundColor3 = Color3.fromRGB(50, 50, 58)
	videoUrlBox.BorderSizePixel = 0
	videoUrlBox.Text = "https://youtu.be/uI065F9UaCA"
	videoUrlBox.TextSize = 12
	videoUrlBox.Font = Enum.Font.Code
	videoUrlBox.TextColor3 = Color3.fromRGB(100, 180, 255)
	videoUrlBox.TextXAlignment = Enum.TextXAlignment.Left
	videoUrlBox.ClearTextOnFocus = false
	videoUrlBox.TextEditable = false
	videoUrlBox.Parent = container

	local videoUrlCorner = Instance.new("UICorner")
	videoUrlCorner.CornerRadius = UDim.new(0, 4)
	videoUrlCorner.Parent = videoUrlBox

	local videoUrlPadding = Instance.new("UIPadding")
	videoUrlPadding.PaddingLeft = UDim.new(0, 8)
	videoUrlPadding.PaddingRight = UDim.new(0, 8)
	videoUrlPadding.Parent = videoUrlBox

	-- Footer note
	local footer = Instance.new("TextLabel")
	footer.Name = "Footer"
	footer.Size = UDim2.new(1, -40, 0, 30)
	footer.Position = UDim2.new(0, 20, 1, -35)
	footer.BackgroundTransparency = 1
	footer.Text = "This window cannot be closed. Enable HttpService and restart."
	footer.TextSize = 11
	footer.Font = Enum.Font.GothamMedium
	footer.TextColor3 = Color3.fromRGB(120, 120, 120)
	footer.Parent = container

	-- Subtle pulse animation on the accent bar
	task.spawn(function()
		while screenGui.Parent do
			local tweenIn = TweenService:Create(
				accentBar,
				TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{ BackgroundColor3 = Color3.fromRGB(255, 200, 100) }
			)
			tweenIn:Play()
			tweenIn.Completed:Wait()

			local tweenOut = TweenService:Create(
				accentBar,
				TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{ BackgroundColor3 = Color3.fromRGB(255, 170, 50) }
			)
			tweenOut:Play()
			tweenOut.Completed:Wait()
		end
	end)

	return screenGui
end

return HttpDisabledUI
