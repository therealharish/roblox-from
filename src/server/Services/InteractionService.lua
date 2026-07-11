--!strict
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local InteractionService = { Buckets = {} }
local loot = { "Scrap", "Scrap", "Cloth", "Cloth", "Medicine", "Bandage" }
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
					local item = loot[math.random(1, #loot)]
					if self.Registry.InventoryService:Add(player, item, 1) then
						crate:SetAttribute("Looted", true)
						descendant.Enabled = false
						self:Toast(player, `Found {item}`)
						self.Registry.QuestService:Record(player, "Loot")
						task.delay(0.1, function() if crate and crate.Parent then crate:Destroy() end end)
					else
						self:Toast(player, "Inventory full")
					end
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
								local closedAngle = hinge:GetAttribute("ClosedAngle") or 0
								if opening then
									local playerRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
									local attachment = hinge.Attachment0 or hinge.Attachment1
									local direction = 1
									if playerRoot and playerRoot:IsA("BasePart") and attachment then
										local pivot = attachment.WorldPosition
										local axis = attachment.WorldAxis
										local doorBounds = doorModel:GetBoundingBox()
										local center = doorBounds.Position
										local relative = center - pivot
										local plusCenter = pivot + CFrame.fromAxisAngle(axis, math.rad(95)):VectorToWorldSpace(relative)
										local minusCenter = pivot + CFrame.fromAxisAngle(axis, math.rad(-95)):VectorToWorldSpace(relative)
										direction = (plusCenter - playerRoot.Position).Magnitude >= (minusCenter - playerRoot.Position).Magnitude and 1 or -1
									end
									-- This template's servo angle is measured around the
									-- opposite attachment axis from WorldAxis prediction.
									hinge.TargetAngle = closedAngle - 95 * direction
								else
									hinge.TargetAngle = closedAngle
								end
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
		elseif action == self.Registry.Protocol.Actions.Sprint and type(payload) == "boolean" then
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid and not player:GetAttribute("Downed") then
				humanoid.WalkSpeed = payload and 25 or 16
				ok, msg = true, ""
			end
		elseif action == self.Registry.Protocol.Actions.Settings and type(payload) == "table" then
			local profile = self.Registry.ProfileService:Get(player)
			if profile then
				for key, value in payload do if profile.settings[key] ~= nil and type(value) == "boolean" then profile.settings[key] = value end end
				ok, msg = true, "Settings saved"
			end
		end
		if msg ~= "" then self:Toast(player, msg) end
	end)
	Players.PlayerRemoving:Connect(function(p) self.Buckets[p] = nil end)
end
return InteractionService
