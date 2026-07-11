--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("Shared")
local Protocol = require(shared:WaitForChild("Protocol"))
local Config = require(shared:WaitForChild("Config"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")

if Config.Audio.AmbientMusicId ~= "" then
	local music = Instance.new("Sound")
	music.Name = "HollowSignalAmbient"
	music.SoundId = Config.Audio.AmbientMusicId
	music.Volume = Config.Audio.MusicVolume
	music.Looped = true
	music.RollOffMode = Enum.RollOffMode.Inverse
	music.Parent = SoundService
	music:Play()
end

local gui = Instance.new("ScreenGui")
gui.Name = "HollowSignalHUD"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local top = Instance.new("Frame")
top.Size = UDim2.fromScale(0.42, 0.105)
top.Position = UDim2.fromScale(0.29, 0.025)
top.BackgroundColor3 = Color3.fromRGB(16, 18, 23)
top.BackgroundTransparency = 0.18
top.Parent = gui
Instance.new("UICorner", top).CornerRadius = UDim.new(0, 10)

local cycle = Instance.new("TextLabel")
cycle.Size = UDim2.fromScale(1, 0.5)
cycle.BackgroundTransparency = 1
cycle.TextColor3 = Color3.fromRGB(240, 230, 207)
cycle.Font = Enum.Font.GothamBold
cycle.TextScaled = true
cycle.Text = "DAY"
cycle.Parent = top

local objective = Instance.new("TextLabel")
objective.Size = UDim2.fromScale(1, 0.42)
objective.Position = UDim2.fromScale(0, 0.53)
objective.BackgroundTransparency = 1
objective.TextColor3 = Color3.fromRGB(190, 201, 193)
objective.Font = Enum.Font.Gotham
objective.TextScaled = true
objective.Text = "Search supplies • Repair wards • Find the signal"
objective.Parent = top

local condition = Instance.new("TextLabel")
condition.Size = UDim2.fromScale(0.22, 0.05)
condition.Position = UDim2.fromScale(0.025, 0.91)
condition.BackgroundColor3 = Color3.fromRGB(16, 18, 23)
condition.BackgroundTransparency = 0.2
condition.TextColor3 = Color3.fromRGB(235, 235, 225)
condition.Font = Enum.Font.GothamBold
condition.TextScaled = true
condition.Parent = gui

local toast = Instance.new("TextLabel")
toast.Size = UDim2.fromScale(0.5, 0.06)
toast.Position = UDim2.fromScale(0.25, 0.78)
toast.BackgroundColor3 = Color3.fromRGB(25, 27, 32)
toast.BackgroundTransparency = 1
toast.TextTransparency = 1
toast.TextColor3 = Color3.fromRGB(245, 221, 164)
toast.Font = Enum.Font.GothamBold
toast.TextScaled = true
toast.Parent = gui

local crafting = Instance.new("Frame")
crafting.Size = UDim2.fromScale(0.28, 0.32)
crafting.Position = UDim2.fromScale(0.36, 0.34)
crafting.BackgroundColor3 = Color3.fromRGB(20, 22, 27)
crafting.Visible = false
crafting.Parent = gui
Instance.new("UICorner", crafting).CornerRadius = UDim.new(0, 10)
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8); layout.HorizontalAlignment = Enum.HorizontalAlignment.Center; layout.VerticalAlignment = Enum.VerticalAlignment.Center; layout.Parent = crafting
for _, recipe in { "Flare", "Noisemaker", "Plank" } do
	local button = Instance.new("TextButton")
	button.Size = UDim2.fromScale(0.82, 0.2)
	button.Text = `Craft {recipe}`
	button.Font = Enum.Font.GothamBold; button.TextScaled = true
	button.BackgroundColor3 = Color3.fromRGB(74, 70, 58); button.TextColor3 = Color3.new(1,1,1)
	button.Parent = crafting
	button.Activated:Connect(function() remotes.Action:FireServer(Protocol.Actions.Craft, recipe) end)
end

local toastToken = 0
local lastPhase = ""
remotes.Toast.OnClientEvent:Connect(function(message)
	toastToken += 1; local token = toastToken
	toast.Text = tostring(message); toast.TextTransparency = 0; toast.BackgroundTransparency = 0.15
	task.delay(3, function() if token == toastToken then toast.TextTransparency = 1; toast.BackgroundTransparency = 1 end end)
end)
remotes.State.OnClientEvent:Connect(function(kind, data)
	if kind == "Cycle" then
		local minutes = math.floor(data.remaining / 60)
		local seconds = data.remaining % 60
		cycle.Text = string.format("%s  %02d:%02d", string.upper(data.phase), minutes, seconds)
		if data.phase ~= lastPhase then
			lastPhase = data.phase
			if data.phase == "Warning" then
				toastToken += 1; toast.Text = "THE FIGURES ARE LEAVING THE TREELINE"; toast.TextTransparency = 0; toast.BackgroundTransparency = 0.15
			elseif data.phase == "Siege" then
				toastToken += 1; toast.Text = "THEY ARE IN THE TOWN"; toast.TextTransparency = 0; toast.BackgroundTransparency = 0.15
			end
		end
	elseif kind == "Quest" then
		objective.Text = `Supplies {data.supplies}/8  •  Ward repairs {data.wards}/2  •  Signal {data.hatch and "FOUND" or "UNKNOWN"}`
	end
end)
local function toggleCraft(_, state)
	if state == Enum.UserInputState.Begin then crafting.Visible = not crafting.Visible end
	return Enum.ContextActionResult.Sink
end
ContextActionService:BindAction("Crafting", toggleCraft, true, Enum.KeyCode.C, Enum.KeyCode.ButtonY)
ContextActionService:SetTitle("Crafting", "Craft")
ContextActionService:SetPosition("Crafting", UDim2.fromScale(0.84, 0.72))

player:GetAttributeChangedSignal("Condition"):Connect(function()
	condition.Text = `CONDITION  {math.floor(player:GetAttribute("Condition") or 100)}`
end)
condition.Text = `CONDITION  {math.floor(player:GetAttribute("Condition") or 100)}`

local function nearestDowned()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	local best, dist = nil, 10
	for _, other in Players:GetPlayers() do
		local otherRoot = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		if other ~= player and other:GetAttribute("Downed") and otherRoot and (root.Position - otherRoot.Position).Magnitude < dist then best = other; dist = (root.Position - otherRoot.Position).Magnitude end
	end
	return best
end
ContextActionService:BindAction("Rescue", function(_, state)
	if state == Enum.UserInputState.Begin then local target = nearestDowned(); if target then remotes.Action:FireServer(Protocol.Actions.Revive, target) end end
	return Enum.ContextActionResult.Pass
end, true, Enum.KeyCode.R, Enum.KeyCode.ButtonX)
ContextActionService:SetTitle("Rescue", "Rescue")
ContextActionService:SetPosition("Rescue", UDim2.fromScale(0.72, 0.72))

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or input.KeyCode ~= Enum.KeyCode.F then return end
	local camera = workspace.CurrentCamera
	local params = RaycastParams.new(); params.FilterDescendantsInstances = { player.Character }; params.FilterType = Enum.RaycastFilterType.Exclude
	local result = workspace:Raycast(camera.CFrame.Position, camera.CFrame.LookVector * 80, params)
	local model = result and result.Instance and result.Instance:FindFirstAncestorOfClass("Model")
	if model and string.find(model.Name, "Wanderer") then remotes.Action:FireServer(Protocol.Actions.Stagger, model) end
end)
