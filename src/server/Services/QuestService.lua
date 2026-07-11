--!strict
local Players = game:GetService("Players")
local QuestService = { Shared = { supplies = 0, wards = 0, hatch = false } }
function QuestService:Init(registry) self.Registry = registry end
function QuestService:Record(player: Player, event: string)
	local profile = self.Registry.ProfileService:Get(player)
	if not profile then return end
	if event == "Loot" then
		self.Shared.supplies += 1
		profile.xp += 5
	elseif event == "RepairWard" then
		self.Shared.wards += 1
		profile.xp += 10
	elseif event == "Clue" and not profile.journal["hatch_signal"] then
		profile.journal["hatch_signal"] = true
		self.Shared.hatch = true
		profile.xp += 50
		self.Registry.Remotes.Toast:FireClient(player, "Journal updated: The signal beneath")
	end
	self:Broadcast()
end
function QuestService:Broadcast()
	self.Registry.Remotes.State:FireAllClients("Quest", self.Shared)
end
function QuestService:Start()
	Players.PlayerAdded:Connect(function(player) task.delay(2, function() if player.Parent then self:Broadcast() end end) end)
end
return QuestService
