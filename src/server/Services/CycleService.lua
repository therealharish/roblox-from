--!strict
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CycleService = { Phase = "Day", Remaining = 0, Night = 0 }
local phases = { "Day", "Warning", "Siege", "Dawn" }
function CycleService:Init(registry) self.Registry = registry end
function CycleService:SetPhase(phase)
	self.Phase = phase
	local scale = RunService:IsStudio() and self.Registry.Config.StudioCycleScale or 1
	self.Remaining = math.max(5, math.floor(self.Registry.Config.Cycle[phase] * scale))
	workspace:SetAttribute("Phase", phase)
	local lightingGoal = {}
	if phase == "Day" then
		lightingGoal = { ClockTime = 9, Brightness = 2.2, Ambient = Color3.fromRGB(90, 94, 100), OutdoorAmbient = Color3.fromRGB(112, 116, 110) }
	elseif phase == "Warning" then
		lightingGoal = { ClockTime = 17.5, Brightness = 1.5, Ambient = Color3.fromRGB(93, 76, 72), OutdoorAmbient = Color3.fromRGB(116, 89, 73) }
	elseif phase == "Siege" then
		self.Night += 1
		lightingGoal = { ClockTime = 0, Brightness = 0.75, Ambient = Color3.fromRGB(25, 31, 44), OutdoorAmbient = Color3.fromRGB(35, 43, 57) }
	elseif phase == "Dawn" then
		lightingGoal = { ClockTime = 5.5, Brightness = 1.2, Ambient = Color3.fromRGB(76, 74, 85), OutdoorAmbient = Color3.fromRGB(105, 91, 92) }
		self.Registry.ConditionService:DawnReset()
		for _, profile in self.Registry.ProfileService.Profiles do profile.stats.nights += 1 end
	end
	TweenService:Create(Lighting, TweenInfo.new(4, Enum.EasingStyle.Sine), lightingGoal):Play()
	local nightLights = phase == "Warning" or phase == "Siege"
	for _, light in CollectionService:GetTagged("NightLight") do
		if light:IsA("Light") then light.Enabled = nightLights end
	end
	local grade = Lighting:FindFirstChild("HollowGrade")
	if grade and grade:IsA("ColorCorrectionEffect") then
		local tint = phase == "Siege" and Color3.fromRGB(173, 191, 211) or Color3.fromRGB(224, 231, 215)
		local saturation = phase == "Siege" and -0.38 or -0.18
		TweenService:Create(grade, TweenInfo.new(4), { TintColor = tint, Saturation = saturation }):Play()
	end
	self.Registry.Remotes.Toast:FireAllClients(`{phase} has begun`)
end
function CycleService:IsNight() return self.Phase == "Siege" end
function CycleService:Start()
	local index = 1
	self:SetPhase(phases[index])
	while task.wait(1) do
		self.Remaining -= 1
		self.Registry.Remotes.State:FireAllClients("Cycle", { phase = self.Phase, remaining = self.Remaining, night = self.Night })
		if self.Remaining <= 0 then index = index % #phases + 1; self:SetPhase(phases[index]) end
	end
end
return CycleService
