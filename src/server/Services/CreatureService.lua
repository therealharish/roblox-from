--!strict
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local CreatureService = { Creatures = {} }

local function groundAt(position: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local result = workspace:Raycast(position + Vector3.new(0, 300, 0), Vector3.new(0, -650, 0), params)
	return result and (result.Position + Vector3.new(0, 3, 0)) or position
end

local function makeCreature(index, origin: Vector3): Model
	local model = Instance.new("Model")
	model.Name = `Wanderer {index}`
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Position = groundAt(origin + Vector3.new((index - 2) * 18, 8, 95))
	root.Color = Color3.fromRGB(35, 36, 43)
	root.Parent = model
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(3, 5, 2)
	body.Position = root.Position + Vector3.new(0, 2.5, 0)
	body.Color = Color3.fromRGB(38, 40, 45)
	body.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root; weld.Part1 = body; weld.Parent = body
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(2.25, 2.25, 2.25)
	head.Position = root.Position + Vector3.new(0, 6.1, 0)
	head.Color = Color3.fromRGB(188, 178, 161)
	head.Parent = model
	local headWeld = Instance.new("WeldConstraint")
	headWeld.Part0 = body; headWeld.Part1 = head; headWeld.Parent = head
	for side = -1, 1, 2 do
		local arm = Instance.new("Part")
		arm.Name = "Arm"
		arm.Size = Vector3.new(0.8, 4.8, 0.8)
		arm.Position = body.Position + Vector3.new(side * 2, -0.1, 0)
		arm.Color = Color3.fromRGB(48, 49, 54)
		arm.Parent = model
		local armWeld = Instance.new("WeldConstraint")
		armWeld.Part0 = body; armWeld.Part1 = arm; armWeld.Parent = arm
	end
	local face = Instance.new("SurfaceGui")
	face.Face = Enum.NormalId.Front; face.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; face.PixelsPerStud = 60; face.Parent = head
	local expression = Instance.new("TextLabel")
	expression.Size = UDim2.fromScale(1, 1); expression.BackgroundTransparency = 1; expression.Text = "· ᴗ ·"; expression.TextColor3 = Color3.fromRGB(30, 25, 23); expression.Font = Enum.Font.GothamBold; expression.TextScaled = true; expression.Parent = face
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(194, 216, 224); glow.Range = 5; glow.Brightness = 0.25; glow.Parent = head
	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = 1e9
	humanoid.Health = 1e9
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model
	model.PrimaryPart = root
	model.Parent = workspace
	pcall(function() root:SetNetworkOwner(nil) end)
	return model
end

local function makePlayerMimic(index: number, origin: Vector3, source: Player?): Model
	if not source then return makeCreature(index, origin) end
	local ok, result = pcall(function()
		local description = Players:GetHumanoidDescriptionFromUserId(source.UserId)
		return Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or not result or not result:IsA("Model") then
		warn("Could not create player mimic; using fallback creature", result)
		return makeCreature(index, origin)
	end
	local model = result
	model.Name = source.DisplayName
	local root = model:FindFirstChild("HumanoidRootPart")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid then model:Destroy(); return makeCreature(index, origin) end
	model.PrimaryPart = root
	model:PivotTo(CFrame.new(groundAt(origin + Vector3.new((index - 2) * 18, 8, 95))))
	humanoid.DisplayName = source.DisplayName
	humanoid.MaxHealth = 1e9; humanoid.Health = 1e9
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	local highlight = Instance.new("Highlight")
	highlight.Name = "UnnaturalTell"
	highlight.FillTransparency = 1
	highlight.OutlineColor = Color3.fromRGB(118, 22, 28)
	highlight.OutlineTransparency = 0.72
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model
	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		local whisper = Instance.new("PointLight")
		whisper.Color = Color3.fromRGB(146, 28, 34); whisper.Range = 4; whisper.Brightness = 0.12; whisper.Parent = head
	end
	model.Parent = workspace
	pcall(function() root:SetNetworkOwner(nil) end)
	return model
end

function CreatureService:Init(registry) self.Registry = registry end
function CreatureService:NearestTarget(position)
	local best, distance = nil, self.Registry.Config.Creature.DetectionRadius
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and not self.Registry.ShelterService:IsSafe(root.Position) and not player:GetAttribute("Downed") then
			local d = (root.Position - position).Magnitude
			if d < distance then best, distance = player, d end
		end
	end
	return best, distance
end
function CreatureService:Stagger(player, model)
	if typeof(model) ~= "Instance" or not table.find(self.Creatures, model) then return false, "Invalid target" end
	if not self.Registry.InventoryService:Consume(player, "Flare", 1) then return false, "Need a Flare" end
	model:SetAttribute("StaggeredUntil", os.clock() + self.Registry.Config.Creature.StaggerSeconds)
	return true, "Creature staggered"
end
function CreatureService:Start()
	local world = workspace:WaitForChild("HollowSignalWorld")
	local origin = world:GetAttribute("MapOrigin") or Vector3.zero
	local sessionPlayers = Players:GetPlayers()
	for i = 1, self.Registry.Config.Creature.Count do
		local source = #sessionPlayers > 0 and sessionPlayers[(i - 1) % #sessionPlayers + 1] or nil
		local creature = makePlayerMimic(i, origin, source)
		creature:SetAttribute("State", "WaitingBeyondTown")
		table.insert(self.Creatures, creature)
	end
	local lastAttack = {}
	while task.wait(0.35) do
		local active = self.Registry.CycleService:IsNight()
		for i, model in self.Creatures do
			local root = model.PrimaryPart
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if not root or not humanoid then continue end
			if not active then
				model:SetAttribute("State", self.Registry.CycleService.Phase == "Warning" and "Approaching" or "WaitingBeyondTown")
				humanoid:MoveTo(groundAt(origin + Vector3.new((i - 2) * 18, 8, 95)))
				continue
			end
			model:SetAttribute("State", "Hunting")
			if (model:GetAttribute("StaggeredUntil") or 0) > os.clock() then humanoid:Move(Vector3.zero); continue end
			local target, distance = self:NearestTarget(root.Position)
			if target then
				local targetRoot = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
				if targetRoot then
					humanoid.WalkSpeed = self.Registry.Config.Creature.ChaseSpeed
					local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 6, AgentCanJump = true })
					local ok = pcall(function() path:ComputeAsync(root.Position, targetRoot.Position) end)
					local waypoints = ok and path.Status == Enum.PathStatus.Success and path:GetWaypoints() or {}
					humanoid:MoveTo(waypoints[2] and waypoints[2].Position or targetRoot.Position)
					if distance <= self.Registry.Config.Creature.AttackRange and os.clock() - (lastAttack[model] or 0) > self.Registry.Config.Creature.AttackCooldown then
						lastAttack[model] = os.clock()
						self.Registry.ConditionService:Damage(target, self.Registry.Config.Creature.AttackDamage)
					end
				end
			else
				humanoid.WalkSpeed = self.Registry.Config.Creature.WalkSpeed
				humanoid:MoveTo(groundAt(origin + Vector3.new(math.sin(os.clock() / 5 + i) * 65, 8, math.cos(os.clock() / 7 + i) * 80)))
			end
		end
	end
end
return CreatureService
