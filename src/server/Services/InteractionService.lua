--!strict
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local InteractionService = { Buckets = {} }
local loot = { "Scrap", "Scrap", "Cloth", "Medicine" }
function InteractionService:Init(registry) self.Registry = registry end
function InteractionService:Allowed(player)
	local now = os.clock()
	local bucket = self.Buckets[player] or { start = now, count = 0 }
	if now - bucket.start >= 1 then bucket = { start = now, count = 0 } end
	bucket.count += 1; self.Buckets[player] = bucket
	return bucket.count <= self.Registry.Config.RemoteRatePerSecond
end
function InteractionService:Toast(player, message) self.Registry.Remotes.Toast:FireClient(player, message) end
function InteractionService:Start()
	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("ProximityPrompt") then
			descendant.Triggered:Connect(function(player)
				local kind = descendant:GetAttribute("Kind")
				if kind == "Loot" then
					local crate = descendant.Parent
					if crate:GetAttribute("Looted") then return self:Toast(player, "Already searched") end
					crate:SetAttribute("Looted", true); descendant.Enabled = false
					local item = loot[math.random(1, #loot)]
					if self.Registry.InventoryService:Add(player, item, 1) then self:Toast(player, `Found {item}`); self.Registry.QuestService:Record(player, "Loot") end
				elseif kind == "RepairWard" then
					local ok, msg = self.Registry.ShelterService:Repair(player, descendant.Parent)
					self:Toast(player, msg); if ok then self.Registry.QuestService:Record(player, "RepairWard") end
				elseif kind == "Craft" then self:Toast(player, "Open crafting with C / controller Y")
				elseif kind == "Clue" then self.Registry.QuestService:Record(player, "Clue") end
				if kind == "Door" then
					local door = descendant.Parent
					if door:IsA("BasePart") then
						local modelRef = descendant:FindFirstChild("DoorModel")
						local doorModel = modelRef and modelRef:IsA("ObjectValue") and modelRef.Value
						local closed = doorModel and doorModel:GetAttribute("ClosedPivot") or door:GetAttribute("ClosedCFrame")
						if typeof(closed) == "CFrame" then
							local opening = not door:GetAttribute("DoorOpen")
							door:SetAttribute("DoorOpen", opening)
							descendant.ActionText = opening and "Close" or "Open"
							local target = opening and (closed * CFrame.Angles(0, math.rad(92), 0)) or closed
							local hinge = doorModel and doorModel:IsA("Model") and doorModel:FindFirstChildWhichIsA("HingeConstraint", true)
							if hinge and hinge:IsA("HingeConstraint") then
								hinge.ActuatorType = Enum.ActuatorType.Servo
								hinge.AngularSpeed = 2.2
								hinge.ServoMaxTorque = 100000
								hinge.TargetAngle = opening and 95 or 0
							elseif doorModel and doorModel:IsA("Model") then
								local pivot = Instance.new("CFrameValue")
								pivot.Value = doorModel:GetPivot()
								local connection = pivot:GetPropertyChangedSignal("Value"):Connect(function() doorModel:PivotTo(pivot.Value) end)
								local tween = TweenService:Create(pivot, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = target })
								tween.Completed:Once(function() connection:Disconnect(); pivot:Destroy() end)
								tween:Play()
							else
								TweenService:Create(door, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = target }):Play()
							end
						end
					end
				end
			end)
		end
	end
	self.Registry.Remotes.Action.OnServerEvent:Connect(function(player, action, payload)
		if not self:Allowed(player) or type(action) ~= "string" then return end
		local ok, msg = false, "Invalid action"
		if action == self.Registry.Protocol.Actions.Craft and type(payload) == "string" then
			ok, msg = self.Registry.InventoryService:Craft(player, payload)
		elseif action == self.Registry.Protocol.Actions.Revive and typeof(payload) == "Instance" and payload:IsA("Player") then
			ok, msg = self.Registry.ConditionService:Revive(player, payload)
		elseif action == self.Registry.Protocol.Actions.Stagger and typeof(payload) == "Instance" then
			ok, msg = self.Registry.CreatureService:Stagger(player, payload)
		elseif action == self.Registry.Protocol.Actions.Settings and type(payload) == "table" then
			local profile = self.Registry.ProfileService:Get(player)
			if profile then
				for key, value in payload do if profile.settings[key] ~= nil and type(value) == "boolean" then profile.settings[key] = value end end
				ok, msg = true, "Settings saved"
			end
		end
		self:Toast(player, msg)
	end)
	Players.PlayerRemoving:Connect(function(p) self.Buckets[p] = nil end)
end
return InteractionService
