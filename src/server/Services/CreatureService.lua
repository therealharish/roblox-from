--!strict
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local CreatureService = { Creatures = {}, AnimationTracks = {}, Paths = {} }

local function groundAt(position: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local result = workspace:Raycast(position + Vector3.new(0, 300, 0), Vector3.new(0, -650, 0), params)
	return result and (result.Position + Vector3.new(0, 3, 0)) or position
end

-- Find the walkable surface below a point, including buildings/parts as well as
-- terrain. This respects authored structures where some spawns are on rooftops.
-- Spawn points can be authored on/inside trees. Sample a small circle around
-- the authored point and pick the lowest surface; the ground is almost always
-- lower than a tree branch or trunk, so this lands monsters on open ground.
local function findOpenGround(center, radius, excludeList)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = excludeList or {}

	local best = nil
	local bestY = math.huge
	local samples = 8
	for s = 0, samples do
		local angle = s * math.pi * 2 / samples
		local offset = s == 0 and Vector3.zero or Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local pos = center + offset
		local result = workspace:Raycast(pos + Vector3.new(0, 500, 0), Vector3.new(0, -1000, 0), params)
		local surface = result and (result.Position + Vector3.new(0, 3, 0)) or pos
		if surface.Y < bestY then
			bestY = surface.Y
			best = surface
		end
	end
	return best or center
end

-- Pick a waypoint far enough ahead that the humanoid doesn't stop/start every
-- tick. Falling back to the target position gives smooth straight-line pursuit
-- when the path is empty or the target is already close.
local function pickPathWaypoint(rootPosition, waypoints, targetPosition)
	for _, wp in ipairs(waypoints) do
		local pos = wp.Position
		if pos and (pos - rootPosition).Magnitude >= 15 then
			return pos
		end
	end
	return targetPosition
end

local function makeCreature(index, origin: Vector3): Model
	local model = Instance.new("Model")
	model.Name = `Wanderer {index}`
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	local angle = index * math.pi * 2 / 4
	root.Position = groundAt(origin + Vector3.new(math.cos(angle) * 48, 8, math.sin(angle) * 48))
	root.Color = Color3.fromRGB(35, 36, 43)
	root.Parent = model
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(3, 5, 2)
	body.Position = root.Position + Vector3.new(0, 2.5, 0)
	body.Color = Color3.fromRGB(38, 40, 45)
	body.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = body
	weld.Parent = body
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(2.25, 2.25, 2.25)
	head.Position = root.Position + Vector3.new(0, 6.1, 0)
	head.Color = Color3.fromRGB(188, 178, 161)
	head.Parent = model
	local headWeld = Instance.new("WeldConstraint")
	headWeld.Part0 = body
	headWeld.Part1 = head
	headWeld.Parent = head
	for side = -1, 1, 2 do
		local arm = Instance.new("Part")
		arm.Name = "Arm"
		arm.Size = Vector3.new(0.8, 4.8, 0.8)
		arm.Position = body.Position + Vector3.new(side * 2, -0.1, 0)
		arm.Color = Color3.fromRGB(48, 49, 54)
		arm.Parent = model
		local armWeld = Instance.new("WeldConstraint")
		armWeld.Part0 = body
		armWeld.Part1 = arm
		armWeld.Parent = arm
	end
	local face = Instance.new("SurfaceGui")
	face.Face = Enum.NormalId.Front
	face.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	face.PixelsPerStud = 60
	face.Parent = head
	local expression = Instance.new("TextLabel")
	expression.Size = UDim2.fromScale(1, 1)
	expression.BackgroundTransparency = 1
	expression.Text = "· ᴗ ·"
	expression.TextColor3 = Color3.fromRGB(30, 25, 23)
	expression.Font = Enum.Font.GothamBold
	expression.TextScaled = true
	expression.Parent = face
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(194, 216, 224)
	glow.Range = 5
	glow.Brightness = 0.25
	glow.Parent = head
	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = 1e9
	humanoid.Health = 1e9
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model
	model.PrimaryPart = root
	model.Parent = workspace
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	return model
end

local ServerStorage = game:GetService("ServerStorage")

local function getNpcTemplate(index)
	local sources = { ServerStorage, workspace }
	for _, parent in ipairs(sources) do
		local folder = parent:FindFirstChild("Info NPCs")
		if folder then
			local children = folder:GetChildren()
			local template = children[(index - 1) % math.max(1, #children) + 1]
			if template and template:IsA("Model") then
				return template
			end
		end
	end
	return nil
end

local function loadCreatureAnimations(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local animator
	for _, child in ipairs(humanoid:GetChildren()) do
		if child:IsA("Animator") then
			animator = child
			break
		end
	end
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local function load(id, name)
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local ok, track = pcall(function()
			return animator:LoadAnimation(anim)
		end)
		if ok and track then
			track.Looped = true
			return track
		else
			warn(string.format("CreatureService: FAILED to load %s animation (%s) for %s", name, id, model.Name))
			return nil
		end
	end

	CreatureService.AnimationTracks[model] = {
		idle = load("rbxassetid://180435571", "idle"),
		walk = load("rbxassetid://180426354", "walk"),
		lastPosition = nil,
	}
end

local function makeNpcCreature(index, origin)
	local template = getNpcTemplate(index)
	if not template then
		warn("CreatureService: Info NPCs not found in ServerStorage or Workspace; using fallback creature")
		return makeCreature(index, origin)
	end
	local model = template:Clone()
	model.Name = `Monster {index}`

	-- Strip NPC behaviour scripts, keep animation/humanoid scripts.
	for _, desc in ipairs(model:GetDescendants()) do
		if desc:IsA("Script") or desc:IsA("LocalScript") then
			local name = desc.Name:lower()
			if
				name:find("dialogue")
				or name:find("chat")
				or name:find("interaction")
				or name:find("click")
				or name:find("talk")
			then
				desc:Destroy()
			end
		end
	end

	local root = model:FindFirstChild("HumanoidRootPart")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid then
		warn("CreatureService: NPC template missing Humanoid/HumanoidRootPart")
		model:Destroy()
		return makeCreature(index, origin)
	end

	model.PrimaryPart = root

	-- R6 rigs stored in ServerStorage often lose or never had the "Root Hip"
	-- Motor6D between HumanoidRootPart and Torso. Without that weld, unanchoring
	-- the body makes the root separate from the torso and the humanoid cannot
	-- actually walk anywhere.
	local torso = model:FindFirstChild("Torso")
	if torso and torso:IsA("BasePart") then
		local hasRootHip = false
		for _, joint in ipairs(model:GetDescendants()) do
			if
				joint:IsA("Motor6D")
				and ((joint.Part0 == root and joint.Part1 == torso) or (joint.Part0 == torso and joint.Part1 == root))
			then
				hasRootHip = true
				break
			end
		end
		if not hasRootHip then
			local rootHip = Instance.new("Motor6D")
			rootHip.Name = "Root Hip"
			rootHip.Part0 = root
			rootHip.Part1 = torso
			rootHip.C0 = root.CFrame:Inverse() * torso.CFrame
			rootHip.C1 = CFrame.new()
			rootHip.Parent = root
		end
	end

	humanoid.PlatformStand = false
	humanoid.AutoRotate = true
	humanoid.DisplayName = ""
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.MaxHealth = 1e9
	humanoid.Health = 1e9

	model:PivotTo(CFrame.new(findOpenGround(origin, 8, {})))

	-- Make sure the NPC can move and collide. The HumanoidRootPart must stay
	-- non-collidable: a collidable root self-collides with the rig's torso/legs
	-- and the humanoid cannot walk, which is why monsters appeared at the
	-- spawn ring but never actually came into town.
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanTouch = true
			local isRoot = part == root
			local isAccessoryHandle = part.Parent and part.Parent:IsA("Accessory")
			part.CanCollide = not isRoot and not isAccessoryHandle
		end
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = "MonsterTell"
	highlight.FillTransparency = 1
	highlight.OutlineColor = Color3.fromRGB(118, 22, 28)
	highlight.OutlineTransparency = 0.72
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model

	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		local whisper = Instance.new("PointLight")
		whisper.Color = Color3.fromRGB(146, 28, 34)
		whisper.Range = 4
		whisper.Brightness = 0.12
		whisper.Parent = head
	end

	loadCreatureAnimations(model)
	model.Parent = workspace
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	return model
end

local function setCreatureVisible(model: Model, visible: boolean)
	if model:GetAttribute("Visible") == visible then
		return
	end
	model:SetAttribute("Visible", visible)
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			if item:GetAttribute("OriginalTransparency") == nil then
				item:SetAttribute("OriginalTransparency", item.Transparency)
			end
			item.Transparency = visible and (item:GetAttribute("OriginalTransparency") or 0) or 1
			-- Keep the root non-collidable even when visible; a collidable
			-- HumanoidRootPart self-collides with the rig and cannot walk.
			if item == model.PrimaryPart then
				item.CanCollide = false
			else
				item.CanCollide = visible
			end
			item.CanTouch = visible
		elseif item:IsA("Decal") then
			if item:GetAttribute("OriginalTransparency") == nil then
				item:SetAttribute("OriginalTransparency", item.Transparency)
			end
			item.Transparency = visible and (item:GetAttribute("OriginalTransparency") or 0) or 1
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
end

function CreatureService:StealAppearance(model: Model, player: Player)
	local mimicHumanoid = model:FindFirstChildOfClass("Humanoid")
	local playerHumanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not mimicHumanoid or not playerHumanoid then
		return
	end
	local ok, description = pcall(function()
		return playerHumanoid:GetAppliedDescription()
	end)
	if ok and description then
		pcall(function()
			mimicHumanoid:ApplyDescription(description)
		end)
		mimicHumanoid.DisplayName = ""
		mimicHumanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
end

function CreatureService:Init(registry)
	self.Registry = registry
end
function CreatureService:NearestTarget(position, maxDistance)
	local best, distance = nil, maxDistance or self.Registry.Config.Creature.DetectionRadius
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and not self.Registry.ShelterService:IsSafe(root.Position) and not player:GetAttribute("Downed") then
			local d = (root.Position - position).Magnitude
			if d < distance then
				best, distance = player, d
			end
		end
	end
	return best, distance
end
function CreatureService:Stagger(player, model)
	if typeof(model) ~= "Instance" or not table.find(self.Creatures, model) then
		return false, "Invalid target"
	end
	if not self.Registry.InventoryService:Consume(player, "Flare", 1) then
		return false, "Need a Flare"
	end
	model:SetAttribute("StaggeredUntil", os.clock() + self.Registry.Config.Creature.StaggerSeconds)
	return true, "Creature staggered"
end
function CreatureService:Start()
	local monsterSpawns = self.Registry.Config.MonsterSpawns
	if #Players:GetPlayers() == 0 then
		Players.PlayerAdded:Wait()
	end
	task.wait(1)
	for i = 1, #monsterSpawns do
		local creature = makeNpcCreature(i, monsterSpawns[i])
		creature:SetAttribute("State", "WaitingBeyondTown")
		creature:SetAttribute("SpawnPosition", monsterSpawns[i])
		setCreatureVisible(creature, false)
		table.insert(self.Creatures, creature)
	end
	local function reconcileCreatures()
		while #self.Creatures < #monsterSpawns do
			local index = #self.Creatures + 1
			local creature = makeNpcCreature(index, monsterSpawns[index])
			creature:SetAttribute("State", "WaitingBeyondTown")
			creature:SetAttribute("SpawnPosition", monsterSpawns[index])
			setCreatureVisible(creature, self.Registry.CycleService:IsNight())
			table.insert(self.Creatures, creature)
		end
		while #self.Creatures > #monsterSpawns do
			local creature = table.remove(self.Creatures)
			self.AnimationTracks[creature] = nil
			self.Paths[creature] = nil
			if creature then
				creature:Destroy()
			end
		end
	end
	Players.PlayerAdded:Connect(function()
		task.delay(1, reconcileCreatures)
	end)
	Players.PlayerRemoving:Connect(function()
		task.delay(1, reconcileCreatures)
	end)

	local monsterSounds = {}
	for _, sound in ipairs(workspace:GetDescendants()) do
		if sound:IsA("Sound") and string.find(string.lower(sound.Name), "^from_monster_audio") then
			sound.RollOffMode = Enum.RollOffMode.Linear
			sound.RollOffMaxDistance = 2000
			sound.RollOffMinDistance = 100
			table.insert(monsterSounds, sound)
		end
	end

	if #monsterSounds == 0 then
		warn("CreatureService: no from_monster_audio sounds found in workspace")
	end
	local MONSTER_AUDIO_RANGE = 80
	local MONSTER_AUDIO_COOLDOWN = 10
	local lastMonsterSoundTime = 0

	local lastAttack = {}
	local lastPhase = nil
	while task.wait(0.35) do
		local phase = self.Registry.CycleService.Phase
		local active = phase == "Siege"
		-- The instant night falls, re-stage every creature at its own fixed
		-- spawn point so each one emerges from its configured location.
		local siegeJustBegan = active and lastPhase ~= "Siege"
		lastPhase = phase
		if siegeJustBegan then
			self.Paths = {}
		end
		for i, model in self.Creatures do
			local root = model.PrimaryPart
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if not root or not humanoid then
				continue
			end
			local spawnPos = model:GetAttribute("SpawnPosition")
			if typeof(spawnPos) ~= "Vector3" then
				spawnPos = monsterSpawns[1] or Vector3.zero
			end
			setCreatureVisible(model, active)
			local tracks = self.AnimationTracks[model]
			if tracks then
				-- R6 rigs from Studio templates often don't report MoveDirection
				-- correctly, so detect movement from actual position change.
				local currentPos = root.Position
				local moved = false
				if tracks.lastPosition then
					moved = (currentPos - tracks.lastPosition).Magnitude > 0.05
				end
				tracks.lastPosition = currentPos
				if moved then
					if tracks.walk and not tracks.walk.IsPlaying then
						tracks.walk:Play()
					end
					if tracks.walk then
						tracks.walk:AdjustSpeed(math.clamp(humanoid.WalkSpeed / 16, 0.5, 2))
					end
					if tracks.idle and tracks.idle.IsPlaying then
						tracks.idle:Stop()
					end
				else
					if tracks.walk and tracks.walk.IsPlaying then
						tracks.walk:Stop()
					end
					if tracks.idle and not tracks.idle.IsPlaying then
						tracks.idle:Play()
					end
				end
			end
			if siegeJustBegan then
				model:PivotTo(CFrame.new(findOpenGround(spawnPos, 8, { model })))
			end
			if not active then
				self.Paths[model] = nil
				model:SetAttribute("State", phase == "Warning" and "Approaching" or "WaitingBeyondTown")
				local waitingAngle = i * math.pi * 2 / #self.Creatures
				humanoid:MoveTo(
					groundAt(spawnPos + Vector3.new(math.cos(waitingAngle) * 12, 8, math.sin(waitingAngle) * 12))
				)
				continue
			end
			model:SetAttribute("State", "Hunting")
			if (model:GetAttribute("StaggeredUntil") or 0) > os.clock() then
				humanoid:Move(Vector3.zero)
				continue
			end
			-- During the siege, creatures track the nearest vulnerable player
			-- across the whole map (not just the DetectionRadius) so they
			-- actually march from the spawn point to wherever you are.
			local target, distance = self:NearestTarget(root.Position, math.huge)
			if target then
				local targetRoot = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
				if targetRoot then
					humanoid.WalkSpeed = self.Registry.Config.Creature.ChaseSpeed
					local targetPos = targetRoot.Position
					local pathEntry = self.Paths[model]
					local shouldRecompute = not pathEntry
						or (pathEntry.target - targetPos).Magnitude > 12
						or os.clock() - pathEntry.computedAt > 1.5
						or #pathEntry.waypoints == 0
					if shouldRecompute then
						local path =
							PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 6, AgentCanJump = true })
						local ok = pcall(function()
							path:ComputeAsync(root.Position, targetPos)
						end)
						local waypoints = ok and path.Status == Enum.PathStatus.Success and path:GetWaypoints() or {}
						pathEntry = {
							waypoints = waypoints,
							target = targetPos,
							computedAt = os.clock(),
						}
						self.Paths[model] = pathEntry
					end
					humanoid:MoveTo(pickPathWaypoint(root.Position, pathEntry.waypoints, targetPos))
					if
						distance <= self.Registry.Config.Creature.AttackRange
						and os.clock() - (lastAttack[model] or 0) > self.Registry.Config.Creature.AttackCooldown
					then
						lastAttack[model] = os.clock()
						self.Registry.ConditionService:Damage(target, self.Registry.Config.Creature.AttackDamage)
						if target:GetAttribute("Downed") then
							self:StealAppearance(model, target)
						end
					end
				end
			else
				self.Paths[model] = nil
				-- No vulnerable player online: hold near the spawn point
				-- instead of drifting off across the map.
				humanoid.WalkSpeed = self.Registry.Config.Creature.WalkSpeed
				humanoid:MoveTo(
					groundAt(
						spawnPos + Vector3.new(math.sin(os.clock() / 5 + i) * 12, 8, math.cos(os.clock() / 7 + i) * 12)
					)
				)
			end
		end

		-- Monster proximity audio: only at night (Siege), one random scary
		-- sound when any monster is near any player. Never overlap, respect a
		-- cooldown, and silence everything the moment night ends so it can't
		-- bleed into daytime.
		if not active then
			for _, sound in ipairs(monsterSounds) do
				if sound.IsPlaying then
					sound:Stop()
				end
			end
		else
			local monsterNearPlayer = false
			for _, player in Players:GetPlayers() do
				local playerRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if playerRoot then
					for _, model in self.Creatures do
						local root = model.PrimaryPart
						if root and (root.Position - playerRoot.Position).Magnitude <= MONSTER_AUDIO_RANGE then
							monsterNearPlayer = true
							break
						end
					end
				end
				if monsterNearPlayer then
					break
				end
			end

			if monsterNearPlayer and #monsterSounds > 0 then
				local anyPlaying = false
				for _, sound in ipairs(monsterSounds) do
					if sound.IsPlaying then
						anyPlaying = true
						break
					end
				end
				if not anyPlaying and os.clock() - lastMonsterSoundTime > MONSTER_AUDIO_COOLDOWN then
					local sound = monsterSounds[math.random(1, #monsterSounds)]
					if sound then
						sound:Play()
						lastMonsterSoundTime = os.clock()
					end
				end
			end
		end
	end
end
return CreatureService
