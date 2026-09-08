local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

-- Safe Container Resolution (Prevents instant CoreGui / PlayerGui detection flags)
local function getSafeContainer()
	if gethui then
		return gethui()
	elseif syn and syn.protect_gui then
		local folder = Instance.new("Folder")
		syn.protect_gui(folder)
		folder.Parent = game:GetService("CoreGui")
		return folder
	else
		return playerGui
	end
end

local targetContainer = getSafeContainer()

-- Clean up existing UIs safely
local existingToggle = targetContainer:FindFirstChild("VVS_ToggleGui")
if existingToggle then existingToggle:Destroy() end
local existingMain = targetContainer:FindFirstChild("VVS_MainGui")
if existingMain then existingMain:Destroy() end

-- Color Palette
local COLOR_BG = Color3.fromRGB(15, 12, 14)
local COLOR_CARD = Color3.fromRGB(24, 18, 22)
local COLOR_CARD_HOVER = Color3.fromRGB(32, 24, 29)
local COLOR_BORDER = Color3.fromRGB(80, 20, 30)
local COLOR_ACCENT = Color3.fromRGB(220, 38, 38)
local COLOR_TEXT = Color3.fromRGB(245, 240, 242)
local COLOR_SUBTEXT = Color3.fromRGB(155, 140, 145)
local COLOR_GREEN = Color3.fromRGB(34, 197, 94)

local autospamActive = false
local currentCPS = 1
local currentInterval = 0.05 -- Adjusted default interval to prevent instant packet floods
local boundKeyCode = nil
local isKeybindListening = false
local safetyModActive = false

-- Dynamic Lazy Loading of VirtualUser to prevent startup scanning
local VirtualUser = nil
local function getVirtualUser()
	if not VirtualUser then
		local success, service = pcall(function()
			return game:GetService("VirtualUser")
		end)
		if success then VirtualUser = service end
	end
	return VirtualUser
end

-- Root ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "VVS_MainGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = targetContainer

-- Styling Helpers
local function applyCorner(inst, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 8)
	c.Parent = inst
end

local function applyStroke(inst, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color or COLOR_BORDER
	s.Thickness = thickness or 1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = inst
	return s
end

local function tweenColor(inst, property, targetColor, duration)
	TweenService:Create(inst, TweenInfo.new(duration or 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		[property] = targetColor
	}):Play()
end

local function makeDraggable(frame, handle)
	handle = handle or frame
	local dragging, dragInput, dragStart, startPos
	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = frame.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end)
	handle.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if input == dragInput and dragging then
			local delta = input.Position - dragStart
			frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)
end

-- Open/Toggle Button
local toggleGui = Instance.new("ScreenGui")
toggleGui.Name = "VVS_ToggleGui"
toggleGui.ResetOnSpawn = false
toggleGui.Parent = targetContainer

local openButton = Instance.new("TextButton")
openButton.Name = "OpenTestButton"
openButton.Size = UDim2.new(0, 110, 0, 38)
openButton.Position = UDim2.new(0, 20, 0.5, -19)
openButton.BackgroundColor3 = COLOR_CARD
openButton.Text = "⚡ VVS HUB"
openButton.TextColor3 = COLOR_TEXT
openButton.Font = Enum.Font.GothamBold
openButton.TextSize = 13
openButton.Parent = toggleGui
applyCorner(openButton, 8)
local openStroke = applyStroke(openButton, COLOR_BORDER, 1.5)

openButton.MouseEnter:Connect(function()
	tweenColor(openButton, "BackgroundColor3", COLOR_CARD_HOVER, 0.15)
	tweenColor(openStroke, "Color", COLOR_ACCENT, 0.15)
end)
openButton.MouseLeave:Connect(function()
	tweenColor(openButton, "BackgroundColor3", COLOR_CARD, 0.15)
	tweenColor(openStroke, "Color", COLOR_BORDER, 0.15)
end)

-- Key System Window
local keyFrame = Instance.new("Frame")
keyFrame.Name = "KeySystemFrame"
keyFrame.Size = UDim2.new(0, 380, 0, 350)
keyFrame.Position = UDim2.new(0.5, -190, 0.5, -175)
keyFrame.BackgroundColor3 = COLOR_BG
keyFrame.Visible = false
keyFrame.Parent = screenGui
applyCorner(keyFrame, 10)
applyStroke(keyFrame, COLOR_BORDER, 1.5)
makeDraggable(keyFrame)

local keyHeader = Instance.new("Frame")
keyHeader.Size = UDim2.new(1, 0, 0, 45)
keyHeader.BackgroundColor3 = COLOR_CARD
keyHeader.Parent = keyFrame
applyCorner(keyHeader, 10)

local keyTitle = Instance.new("TextLabel")
keyTitle.Size = UDim2.new(1, -20, 1, 0)
keyTitle.Position = UDim2.new(0, 15, 0, 0)
keyTitle.BackgroundTransparency = 1
keyTitle.Text = "🔑 VVS KEY SYSTEM"
keyTitle.TextColor3 = COLOR_TEXT
keyTitle.Font = Enum.Font.GothamBold
keyTitle.TextSize = 14
keyTitle.TextXAlignment = Enum.TextXAlignment.Left
keyTitle.Parent = keyHeader

local tabHolder = Instance.new("Frame")
tabHolder.Size = UDim2.new(1, -24, 0, 32)
tabHolder.Position = UDim2.new(0, 12, 0, 55)
tabHolder.BackgroundTransparency = 1
tabHolder.Parent = keyFrame

local mainTabBtn = Instance.new("TextButton")
mainTabBtn.Size = UDim2.new(0.48, 0, 1, 0)
mainTabBtn.BackgroundColor3 = COLOR_ACCENT
mainTabBtn.Text = "MAIN"
mainTabBtn.TextColor3 = COLOR_TEXT
mainTabBtn.Font = Enum.Font.GothamBold
mainTabBtn.TextSize = 12
mainTabBtn.Parent = tabHolder
applyCorner(mainTabBtn, 6)

local creditsTabBtn = Instance.new("TextButton")
creditsTabBtn.Size = UDim2.new(0.48, 0, 1, 0)
creditsTabBtn.Position = UDim2.new(0.52, 0, 0, 0)
creditsTabBtn.BackgroundColor3 = COLOR_CARD
creditsTabBtn.Text = "CREDITS"
creditsTabBtn.TextColor3 = COLOR_SUBTEXT
creditsTabBtn.Font = Enum.Font.GothamBold
creditsTabBtn.TextSize = 12
creditsTabBtn.Parent = tabHolder
applyCorner(creditsTabBtn, 6)

local mainTabContent = Instance.new("Frame")
mainTabContent.Size = UDim2.new(1, -24, 0, 240)
mainTabContent.Position = UDim2.new(0, 12, 0, 95)
mainTabContent.BackgroundTransparency = 1
mainTabContent.Parent = keyFrame

local creditsTabContent = Instance.new("Frame")
creditsTabContent.Size = UDim2.new(1, -24, 0, 240)
creditsTabContent.Position = UDim2.new(0, 12, 0, 95)
creditsTabContent.BackgroundTransparency = 1
creditsTabContent.Visible = false
creditsTabContent.Parent = keyFrame

local creditsLabel = Instance.new("TextLabel")
creditsLabel.Size = UDim2.new(1, 0, 1, 0)
creditsLabel.BackgroundTransparency = 1
creditsLabel.Text = "Created by VVSAINTZ DEV\n\nOptimized & Enhanced UI"
creditsLabel.TextColor3 = COLOR_SUBTEXT
creditsLabel.Font = Enum.Font.GothamMedium
creditsLabel.TextSize = 14
creditsLabel.Parent = creditsTabContent

local keyTextBox = Instance.new("TextBox")
keyTextBox.Size = UDim2.new(1, 0, 0, 38)
keyTextBox.Position = UDim2.new(0, 0, 0, 5)
keyTextBox.BackgroundColor3 = COLOR_CARD
keyTextBox.PlaceholderText = "Enter Key Here..."
keyTextBox.PlaceholderColor3 = COLOR_SUBTEXT
keyTextBox.Text = ""
keyTextBox.TextColor3 = COLOR_TEXT
keyTextBox.Font = Enum.Font.Gotham
keyTextBox.TextSize = 13
keyTextBox.Parent = mainTabContent
applyCorner(keyTextBox, 6)
applyStroke(keyTextBox, COLOR_BORDER, 1)

local getKeyBtn = Instance.new("TextButton")
getKeyBtn.Size = UDim2.new(1, 0, 0, 36)
getKeyBtn.Position = UDim2.new(0, 0, 0, 50)
getKeyBtn.BackgroundColor3 = COLOR_CARD
getKeyBtn.Text = "Get Key (Copy Discord Link)"
getKeyBtn.TextColor3 = COLOR_SUBTEXT
getKeyBtn.Font = Enum.Font.GothamBold
getKeyBtn.TextSize = 12
getKeyBtn.Parent = mainTabContent
applyCorner(getKeyBtn, 6)
applyStroke(getKeyBtn, COLOR_BORDER, 1)

local fallbackLabel = Instance.new("TextLabel")
fallbackLabel.Size = UDim2.new(1, 0, 0, 30)
fallbackLabel.Position = UDim2.new(0, 0, 0, 90)
fallbackLabel.BackgroundTransparency = 1
fallbackLabel.Text = "sorry if it isnt working its being fixed link is: https://discord.gg/Dd5gXEAWTP"
fallbackLabel.TextColor3 = COLOR_SUBTEXT
fallbackLabel.Font = Enum.Font.Gotham
fallbackLabel.TextSize = 10
fallbackLabel.TextWrapped = true
fallbackLabel.Parent = mainTabContent

local executeKeyBtn = Instance.new("TextButton")
executeKeyBtn.Size = UDim2.new(1, 0, 0, 40)
executeKeyBtn.Position = UDim2.new(0, 0, 0, 128)
executeKeyBtn.BackgroundColor3 = COLOR_ACCENT
executeKeyBtn.Text = "UNLOCK HUB"
executeKeyBtn.TextColor3 = COLOR_TEXT
executeKeyBtn.Font = Enum.Font.GothamBold
executeKeyBtn.TextSize = 13
executeKeyBtn.Parent = mainTabContent
applyCorner(executeKeyBtn, 6)

local statusMsg = Instance.new("TextLabel")
statusMsg.Size = UDim2.new(1, 0, 0, 25)
statusMsg.Position = UDim2.new(0, 0, 0, 175)
statusMsg.BackgroundTransparency = 1
statusMsg.Text = ""
statusMsg.TextColor3 = COLOR_ACCENT
statusMsg.Font = Enum.Font.Gotham
statusMsg.TextSize = 12
statusMsg.Parent = mainTabContent

mainTabBtn.MouseButton1Click:Connect(function()
	mainTabContent.Visible = true
	creditsTabContent.Visible = false
	tweenColor(mainTabBtn, "BackgroundColor3", COLOR_ACCENT, 0.15)
	mainTabBtn.TextColor3 = COLOR_TEXT
	tweenColor(creditsTabBtn, "BackgroundColor3", COLOR_CARD, 0.15)
	creditsTabBtn.TextColor3 = COLOR_SUBTEXT
end)

creditsTabBtn.MouseButton1Click:Connect(function()
	mainTabContent.Visible = false
	creditsTabContent.Visible = true
	tweenColor(creditsTabBtn, "BackgroundColor3", COLOR_ACCENT, 0.15)
	creditsTabBtn.TextColor3 = COLOR_TEXT
	tweenColor(mainTabBtn, "BackgroundColor3", COLOR_CARD, 0.15)
	mainTabBtn.TextColor3 = COLOR_SUBTEXT
end)

getKeyBtn.MouseButton1Click:Connect(function()
	local link = "https://discord.gg/Dd5gXEAWTP"
	local copyFunc = setclipboard or (toclipboard and toclipboard) or (Clipboard and Clipboard.set)
	if copyFunc then
		copyFunc(link)
		statusMsg.TextColor3 = COLOR_GREEN
		statusMsg.Text = "Link copied to clipboard!"
	else
		statusMsg.TextColor3 = COLOR_ACCENT
		statusMsg.Text = "Clipboard not supported by executor."
	end
	task.delay(2.5, function() statusMsg.Text = "" end)
end)

-- Main Hub Window
local autoSpamFrame = Instance.new("Frame")
autoSpamFrame.Name = "AutoSpamMainHub"
autoSpamFrame.Size = UDim2.new(0, 380, 0, 480)
autoSpamFrame.Position = UDim2.new(0.5, -190, 0.5, -240)
autoSpamFrame.BackgroundColor3 = COLOR_BG
autoSpamFrame.Visible = false
autoSpamFrame.Parent = screenGui
applyCorner(autoSpamFrame, 10)
applyStroke(autoSpamFrame, COLOR_BORDER, 1.5)
makeDraggable(autoSpamFrame)

local hubHeader = Instance.new("Frame")
hubHeader.Size = UDim2.new(1, 0, 0, 45)
hubHeader.BackgroundColor3 = COLOR_CARD
hubHeader.Parent = autoSpamFrame
applyCorner(hubHeader, 10)

local hubTitle = Instance.new("TextLabel")
hubTitle.Size = UDim2.new(1, -50, 1, 0)
hubTitle.Position = UDim2.new(0, 15, 0, 0)
hubTitle.BackgroundTransparency = 1
hubTitle.Text = "VVSAINTZ AUTOSPAM HUB"
hubTitle.TextColor3 = COLOR_TEXT
hubTitle.Font = Enum.Font.GothamBold
hubTitle.TextSize = 13
hubTitle.TextXAlignment = Enum.TextXAlignment.Left
hubTitle.Parent = hubHeader

local topCornerClose = Instance.new("TextButton")
topCornerClose.Size = UDim2.new(0, 26, 0, 26)
topCornerClose.Position = UDim2.new(1, -34, 0.5, -13)
topCornerClose.BackgroundColor3 = COLOR_BG
topCornerClose.Text = "✕"
topCornerClose.TextColor3 = COLOR_SUBTEXT
topCornerClose.Font = Enum.Font.GothamBold
topCornerClose.TextSize = 12
topCornerClose.Parent = hubHeader
applyCorner(topCornerClose, 6)

topCornerClose.MouseButton1Click:Connect(function()
	autoSpamFrame.Visible = false
end)

openButton.MouseButton1Click:Connect(function()
	if autoSpamFrame.Visible or keyFrame.Visible then
		autoSpamFrame.Visible = false
		keyFrame.Visible = false
	else
		if autoSpamFrame:GetAttribute("Unlocked") == true then
			autoSpamFrame.Visible = true
		else
			keyFrame.Visible = true
		end
	end
end)

local contentScroll = Instance.new("ScrollingFrame")
contentScroll.Size = UDim2.new(1, -16, 1, -55)
contentScroll.Position = UDim2.new(0, 8, 0, 50)
contentScroll.BackgroundTransparency = 1
contentScroll.ScrollBarThickness = 3
contentScroll.ScrollBarImageColor3 = COLOR_BORDER
contentScroll.CanvasSize = UDim2.new(0, 0, 0, 520)
contentScroll.Parent = autoSpamFrame

local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, 8)
listLayout.Parent = contentScroll

local function createSection(height, layoutOrder)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, -6, 0, height)
	f.BackgroundColor3 = COLOR_CARD
	f.LayoutOrder = layoutOrder
	f.Parent = contentScroll
	applyCorner(f, 8)
	applyStroke(f, COLOR_BORDER, 1)
	return f
end

-- Section 1: Toggle
local sec1 = createSection(52, 1)
local autoSpamTitle = Instance.new("TextLabel")
autoSpamTitle.Size = UDim2.new(0.6, 0, 1, 0)
autoSpamTitle.Position = UDim2.new(0, 12, 0, 0)
autoSpamTitle.BackgroundTransparency = 1
autoSpamTitle.Text = "AutoSpam Enabled"
autoSpamTitle.TextColor3 = COLOR_TEXT
autoSpamTitle.Font = Enum.Font.GothamBold
autoSpamTitle.TextSize = 13
autoSpamTitle.TextXAlignment = Enum.TextXAlignment.Left
autoSpamTitle.Parent = sec1

local toggleSwitchBtn = Instance.new("TextButton")
toggleSwitchBtn.Size = UDim2.new(0, 70, 0, 28)
toggleSwitchBtn.Position = UDim2.new(1, -82, 0.5, -14)
toggleSwitchBtn.BackgroundColor3 = COLOR_BG
toggleSwitchBtn.Text = "OFF"
toggleSwitchBtn.TextColor3 = COLOR_SUBTEXT
toggleSwitchBtn.Font = Enum.Font.GothamBold
toggleSwitchBtn.TextSize = 12
toggleSwitchBtn.Parent = sec1
applyCorner(toggleSwitchBtn, 14)
local toggleStroke = applyStroke(toggleSwitchBtn, COLOR_BORDER, 1)

-- Section 2: Clicks per burst
local sec2 = createSection(70, 2)
local clicksLabel = Instance.new("TextLabel")
clicksLabel.Size = UDim2.new(1, -24, 0, 22)
clicksLabel.Position = UDim2.new(0, 12, 0, 8)
clicksLabel.BackgroundTransparency = 1
clicksLabel.Text = "Clicks Per Burst:"
clicksLabel.TextColor3 = COLOR_TEXT
clicksLabel.Font = Enum.Font.Gotham
clicksLabel.TextSize = 12
clicksLabel.TextXAlignment = Enum.TextXAlignment.Left
clicksLabel.Parent = sec2

local clicksInput = Instance.new("TextBox")
clicksInput.Size = UDim2.new(1, -24, 0, 28)
clicksInput.Position = UDim2.new(0, 12, 0, 32)
clicksInput.BackgroundColor3 = COLOR_BG
clicksInput.Text = "1"
clicksInput.TextColor3 = COLOR_TEXT
clicksInput.Font = Enum.Font.GothamBold
clicksInput.TextSize = 12
clicksInput.Parent = sec2
applyCorner(clicksInput, 6)
applyStroke(clicksInput, COLOR_BORDER, 1)

-- Section 3: Interval Speed
local sec3 = createSection(70, 3)
local intervalLabel = Instance.new("TextLabel")
intervalLabel.Size = UDim2.new(1, -24, 0, 22)
intervalLabel.Position = UDim2.new(0, 12, 0, 8)
intervalLabel.BackgroundTransparency = 1
intervalLabel.Text = "Interval Speed (Seconds):"
intervalLabel.TextColor3 = COLOR_TEXT
intervalLabel.Font = Enum.Font.Gotham
intervalLabel.TextSize = 12
intervalLabel.TextXAlignment = Enum.TextXAlignment.Left
intervalLabel.Parent = sec3

local intervalInput = Instance.new("TextBox")
intervalInput.Size = UDim2.new(1, -24, 0, 28)
intervalInput.Position = UDim2.new(0, 12, 0, 32)
intervalInput.BackgroundColor3 = COLOR_BG
intervalInput.Text = "0.05"
intervalInput.TextColor3 = COLOR_TEXT
intervalInput.Font = Enum.Font.GothamBold
intervalInput.TextSize = 12
intervalInput.Parent = sec3
applyCorner(intervalInput, 6)
applyStroke(intervalInput, COLOR_BORDER, 1)

-- Section 4: Keybind
local sec4 = createSection(52, 4)
local keybindTitle = Instance.new("TextLabel")
keybindTitle.Size = UDim2.new(0.5, 0, 1, 0)
keybindTitle.Position = UDim2.new(0, 12, 0, 0)
keybindTitle.BackgroundTransparency = 1
keybindTitle.Text = "Hold Keybind:"
keybindTitle.TextColor3 = COLOR_TEXT
keybindTitle.Font = Enum.Font.Gotham
keybindTitle.TextSize = 12
keybindTitle.TextXAlignment = Enum.TextXAlignment.Left
keybindTitle.Parent = sec4

local keybindBtn = Instance.new("TextButton")
keybindBtn.Size = UDim2.new(0, 110, 0, 28)
keybindBtn.Position = UDim2.new(1, -122, 0.5, -14)
keybindBtn.BackgroundColor3 = COLOR_BG
keybindBtn.Text = "NONE"
keybindBtn.TextColor3 = COLOR_SUBTEXT
keybindBtn.Font = Enum.Font.GothamBold
keybindBtn.TextSize = 11
keybindBtn.Parent = sec4
applyCorner(keybindBtn, 6)
applyStroke(keybindBtn, COLOR_BORDER, 1)

-- Section 5: Safety Mod
local sec5 = createSection(85, 5)
local safetyTitle = Instance.new("TextLabel")
safetyTitle.Size = UDim2.new(0.6, 0, 0, 22)
safetyTitle.Position = UDim2.new(0, 12, 0, 8)
safetyTitle.BackgroundTransparency = 1
safetyTitle.Text = "Safety Mod"
safetyTitle.TextColor3 = COLOR_TEXT
safetyTitle.Font = Enum.Font.GothamBold
safetyTitle.TextSize = 12
safetyTitle.TextXAlignment = Enum.TextXAlignment.Left
safetyTitle.Parent = sec5

local safetyToggleBtn = Instance.new("TextButton")
safetyToggleBtn.Size = UDim2.new(0, 60, 0, 24)
safetyToggleBtn.Position = UDim2.new(1, -72, 0, 8)
safetyToggleBtn.BackgroundColor3 = COLOR_BG
safetyToggleBtn.Text = "OFF"
safetyToggleBtn.TextColor3 = COLOR_SUBTEXT
safetyToggleBtn.Font = Enum.Font.GothamBold
safetyToggleBtn.TextSize = 11
safetyToggleBtn.Parent = sec5
applyCorner(safetyToggleBtn, 12)
local safetyStroke = applyStroke(safetyToggleBtn, COLOR_BORDER, 1)

local safetyDesc = Instance.new("TextLabel")
safetyDesc.Size = UDim2.new(1, -24, 0, 40)
safetyDesc.Position = UDim2.new(0, 12, 0, 36)
safetyDesc.BackgroundTransparency = 1
safetyDesc.Text = "Auto-disconnects if a Mod, Admin, or Place Owner joins the game."
safetyDesc.TextColor3 = COLOR_SUBTEXT
safetyDesc.Font = Enum.Font.Gotham
safetyDesc.TextSize = 10
safetyDesc.TextWrapped = true
safetyDesc.TextXAlignment = Enum.TextXAlignment.Left
safetyDesc.Parent = sec5

-- Section 6: Action Buttons
local sec6 = createSection(90, 6)
local rejoinBtn = Instance.new("TextButton")
rejoinBtn.Size = UDim2.new(1, -24, 0, 32)
rejoinBtn.Position = UDim2.new(0, 12, 0, 8)
rejoinBtn.BackgroundColor3 = COLOR_CARD_HOVER
rejoinBtn.Text = "Rejoin Server"
rejoinBtn.TextColor3 = COLOR_TEXT
rejoinBtn.Font = Enum.Font.GothamBold
rejoinBtn.TextSize = 12
rejoinBtn.Parent = sec6
applyCorner(rejoinBtn, 6)
applyStroke(rejoinBtn, COLOR_BORDER, 1)

local closeAllBtn = Instance.new("TextButton")
closeAllBtn.Size = UDim2.new(1, -24, 0, 32)
closeAllBtn.Position = UDim2.new(0, 12, 0, 48)
closeAllBtn.BackgroundColor3 = COLOR_BG
closeAllBtn.Text = "Close UI & Unload"
closeAllBtn.TextColor3 = COLOR_ACCENT
closeAllBtn.Font = Enum.Font.GothamBold
closeAllBtn.TextSize = 12
closeAllBtn.Parent = sec6
applyCorner(closeAllBtn, 6)
applyStroke(closeAllBtn, COLOR_BORDER, 1)

-- Key Validation Logic
local isEvaluatingKey = false
executeKeyBtn.MouseButton1Click:Connect(function()
	if isEvaluatingKey then return end
	if keyTextBox.Text == "VVSAINTZONTOP" then
		statusMsg.TextColor3 = COLOR_GREEN
		statusMsg.Text = "ACCESS GRANTED!"
		task.wait(0.4)
		keyFrame.Visible = false
		autoSpamFrame.Visible = true
		autoSpamFrame:SetAttribute("Unlocked", true)
	else
		isEvaluatingKey = true
		keyTextBox.Text = ""
		keyTextBox.PlaceholderText = "WRONG KEY!"
		statusMsg.Text = "Incorrect Key!"
		task.delay(1.5, function()
			keyTextBox.PlaceholderText = "Enter Key Here..."
			statusMsg.Text = ""
			isEvaluatingKey = false
		end)
	end
end)

-- Input Validation
clicksInput.FocusLost:Connect(function()
	local num = tonumber(clicksInput.Text)
	currentCPS = (num and num > 0) and math.floor(num) or 1
	clicksInput.Text = tostring(currentCPS)
end)

intervalInput.FocusLost:Connect(function()
	local num = tonumber(intervalInput.Text)
	currentInterval = (num and num >= 0) and num or 0.05
	intervalInput.Text = tostring(currentInterval)
end)

local function setAutospam(state)
	autospamActive = state
	if autospamActive then
		toggleSwitchBtn.Text = "ON"
		toggleSwitchBtn.TextColor3 = COLOR_TEXT
		tweenColor(toggleSwitchBtn, "BackgroundColor3", COLOR_ACCENT, 0.15)
		tweenColor(toggleStroke, "Color", COLOR_ACCENT, 0.15)
	else
		toggleSwitchBtn.Text = "OFF"
		toggleSwitchBtn.TextColor3 = COLOR_SUBTEXT
		tweenColor(toggleSwitchBtn, "BackgroundColor3", COLOR_BG, 0.15)
		tweenColor(toggleStroke, "Color", COLOR_BORDER, 0.15)
	end
end

toggleSwitchBtn.MouseButton1Click:Connect(function()
	setAutospam(not autospamActive)
end)

keybindBtn.MouseButton1Click:Connect(function()
	isKeybindListening = true
	keybindBtn.Text = "PRESS KEY..."
	keybindBtn.TextColor3 = COLOR_ACCENT
end)

UserInputService.InputBegan:Connect(function(input, gpe)
	if isKeybindListening then
		if input.UserInputType == Enum.UserInputType.Keyboard then
			if input.KeyCode == Enum.KeyCode.Escape then
				boundKeyCode = nil
				keybindBtn.Text = "NONE"
			else
				boundKeyCode = input.KeyCode
				keybindBtn.Text = boundKeyCode.Name
			end
			keybindBtn.TextColor3 = COLOR_TEXT
			isKeybindListening = false
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2 then
			boundKeyCode = nil
			keybindBtn.Text = "NONE"
			keybindBtn.TextColor3 = COLOR_SUBTEXT
			isKeybindListening = false
		end
	end
end)

-- Safe UI Hover Checker
local function isMouseOverGui()
	local mousePos = UserInputService:GetMouseLocation()
	local guiObjects = playerGui:GetGuiObjectsAtPosition(mousePos.X, mousePos.Y)
	for _, obj in ipairs(guiObjects) do
		if obj:IsDescendantOf(screenGui) or obj:IsDescendantOf(toggleGui) then
			return true
		end
	end
	return false
end

-- Optimized Loop with Delay Protection
task.spawn(function()
	while screenGui and screenGui.Parent do
		if currentInterval <= 0 then
			RunService.RenderStepped:Wait()
		else
			task.wait(currentInterval)
		end
		
		if autospamActive then
			local mouseOverUI = isMouseOverGui()
			local shouldClick = (boundKeyCode == nil) or UserInputService:IsKeyDown(boundKeyCode)
			
			if shouldClick and not mouseOverUI then
				local vu = getVirtualUser()
				if vu then
					vu:CaptureController()
					for i = 1, currentCPS do
						vu:ClickButton1(Vector2.new(100, 100))
					end
				end
			end
		end
	end
end)

-- Slowed-Down Safety Mod Check Loop to Avoid CPU/Thread Flags
local function checkPlayerSafety(plr)
	if not safetyModActive then return end
	local nameLower = plr.Name:lower()
	if string.find(nameLower, "mod") or string.find(nameLower, "admin") or plr.UserId == game.CreatorId then
		localPlayer:Kick("\n[VVS Safety Mod]\nStaff/Admin detected in server: " .. plr.Name)
	end
end

safetyToggleBtn.MouseButton1Click:Connect(function()
	safetyModActive = not safetyModActive
	if safetyModActive then
		safetyToggleBtn.Text = "ON"
		safetyToggleBtn.TextColor3 = COLOR_TEXT
		tweenColor(safetyToggleBtn, "BackgroundColor3", COLOR_ACCENT, 0.15)
		tweenColor(safetyStroke, "Color", COLOR_ACCENT, 0.15)
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= localPlayer then checkPlayerSafety(p) end
		end
	else
		safetyToggleBtn.Text = "OFF"
		safetyToggleBtn.TextColor3 = COLOR_SUBTEXT
		tweenColor(safetyToggleBtn, "BackgroundColor3", COLOR_BG, 0.15)
		tweenColor(safetyStroke, "Color", COLOR_BORDER, 0.15)
	end
end)

-- Delayed event registration
task.delay(1, function()
	Players.PlayerAdded:Connect(checkPlayerSafety)
end)

rejoinBtn.MouseButton1Click:Connect(function()
	if #Players:GetPlayers() <= 1 then
		TeleportService:Teleport(game.PlaceId, localPlayer)
	else
		TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, localPlayer)
	end
end)

closeAllBtn.MouseButton1Click:Connect(function()
	autospamActive = false
	safetyModActive = false
	screenGui:Destroy()
	toggleGui:Destroy()
end)
