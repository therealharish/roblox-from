--!strict
local Players = game:GetService("Players")
local ConditionService = { Downed = {} }
function ConditionService:Init(registry) self.Registry = registry end
function ConditionService:SetCondition(player, value)
	value = math.clamp(value, 0, self.Registry.Config.Player.MaxCondition)
	player:SetAttribute("Condition", value)
	if value <= 0 and not self.Downed[player] then self:Down(player) end
end
function ConditionService:Damage(player, amount)
	if self.Downed[player] then return end
	self:SetCondition(player, (player:GetAttribute("Condition") or 100) - amount)
end
function ConditionService:Down(player)
	self.Downed[player] = os.clock() + self.Registry.Config.Player.DownedSeconds
	player:SetAttribute("Downed", true)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid.WalkSpeed = 4; humanoid.JumpPower = 0 end
	self.Registry.Remotes.Toast:FireAllClients(`{player.DisplayName} needs rescue!`)
end
function ConditionService:Revive(rescuer, target)
	if not self.Downed[target] then return false, "Player is not downed" end
	local a = rescuer.Character and rescuer.Character:FindFirstChild("HumanoidRootPart")
	local b = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
	if not a or not b or (a.Position - b.Position).Magnitude > 10 then return false, "Move closer" end
	self.Downed[target] = nil
	target:SetAttribute("Downed", false)
	self:SetCondition(target, 35)
	local humanoid = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid.WalkSpeed = 16; humanoid.JumpPower = 50 end
	local profile = self.Registry.ProfileService:Get(rescuer)
	if profile then profile.stats.rescues += 1; profile.xp += 20 end
	return true, `Rescued {target.DisplayName}`
end
function ConditionService:DawnReset()
	for player in self.Downed do
		self.Downed[player] = nil
		player:SetAttribute("Downed", false)
		self:SetCondition(player, 60)
		player:LoadCharacter()
	end
end
function ConditionService:Start()
	local function setup(player)
		player:SetAttribute("Condition", 100)
		player.CharacterAdded:Connect(function() if not self.Downed[player] then self:SetCondition(player, 100) end end)
	end
	Players.PlayerAdded:Connect(setup)
	Players.PlayerRemoving:Connect(function(p) self.Downed[p] = nil end)
	for _, p in Players:GetPlayers() do setup(p) end
	task.spawn(function()
		while task.wait(1) do
			for player, deadline in self.Downed do
				if os.clock() >= deadline then
					local profile = self.Registry.ProfileService:Get(player)
					if profile then profile.inventory = {} end
					self.Downed[player] = math.huge
					self.Registry.Remotes.Toast:FireClient(player, "You will return at dawn. Carried supplies were lost.")
				end
			end
		end
	end)
end
return ConditionService
