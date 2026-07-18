--!strict
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")

local WorldService = {}

-- The authored point is usually a tree/model location, not the ground.
-- Sample a circle around it, keep only fairly-flat surfaces (floors/terrain),
-- prefer the lowest flat surface so we don't land on a roof/branch, but also
-- pick the one closest to the reference so the crate stays "near" the object.
local function findSupplyGround(referencePosition)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {}

	local radius = 16
	local samples = 16
	local candidates = {}

	table.insert(candidates, referencePosition)
	for s = 1, samples do
		local angle = s * math.pi * 2 / samples
		table.insert(candidates, referencePosition + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius))
	end

	local flatSurfaces = {}
	local lowestY = math.huge
	for _, pos in ipairs(candidates) do
		local result = workspace:Raycast(pos + Vector3.new(0, 100, 0), Vector3.new(0, -200, 0), params)
		if result and result.Normal.Y >= 0.8 then
			table.insert(flatSurfaces, {
				position = result.Position,
				distance = (result.Position - referencePosition).Magnitude,
			})
			lowestY = math.min(lowestY, result.Position.Y)
		end
	end

	if #flatSurfaces > 0 then
		local best = nil
		local bestDistance = math.huge
		for _, surf in ipairs(flatSurfaces) do
			if surf.position.Y <= lowestY + 3 and surf.distance < bestDistance then
				best = surf
				bestDistance = surf.distance
			end
		end
		if best then
			return best.position + Vector3.new(0, 1, 0)
		end
	end

	local bestAny = nil
	local bestAnyY = math.huge
	for _, pos in ipairs(candidates) do
		local result = workspace:Raycast(pos + Vector3.new(0, 100, 0), Vector3.new(0, -200, 0), params)
		if result and result.Position.Y < bestAnyY then
			bestAnyY = result.Position.Y
			bestAny = result.Position
		end
	end
	if bestAny then
		return bestAny + Vector3.new(0, 1, 0)
	end

	return referencePosition
end

local function part(name: string, size: Vector3, position: Vector3, color: Color3, parent: Instance, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Position = position
	p.Anchored = true
	p.Color = color
	p.Material = material or Enum.Material.WoodPlanks
	p.Parent = parent
	return p
end

local function prompt(target: BasePart, action: string, object: string, kind: string): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = 0.35
	p.MaxActivationDistance = 10
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.RequiresLineOfSight = false
	p:SetAttribute("Kind", kind)
	p.Parent = target
	return p
end

local function surfaceText(target: BasePart, text: string, face: Enum.NormalId, color: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 28
	gui.Parent = target
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.65
	label.Font = Enum.Font.SpecialElite
	label.TextScaled = true
	label.Parent = gui
end

local function window(root: Instance, position: Vector3, size: Vector3)
	local frame = part("WindowFrame", size + Vector3.new(0.5, 0.5, 0.3), position, Color3.fromRGB(48, 38, 31), root)
	local glass = part("Window", size, position + Vector3.new(0, 0, -0.18), Color3.fromRGB(234, 190, 103), root, Enum.Material.Glass)
	glass.Transparency = 0.22
	glass.CanCollide = false
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Front
	light.Range = 13
	light.Brightness = 1.2
	light.Color = Color3.fromRGB(255, 190, 103)
	light.Enabled = false
	light.Parent = glass
	CollectionService:AddTag(light, "NightLight")
	return frame
end

local function organicTree(root: Instance, index: number, position: Vector3)
	local height = 25 + (index % 9)
	local trunk = part(`Tree{index}`, Vector3.new(height, 3.2 + index % 2, 3.2 + index % 2), position + Vector3.new(0, height / 2, 0), Color3.fromRGB(54, 39, 30), root, Enum.Material.Wood)
	trunk.Shape = Enum.PartType.Cylinder
	trunk.CFrame = CFrame.new(trunk.Position) * CFrame.Angles(0, 0, math.rad(90))
	for branch = 1, 4 do
		local angle = branch * 1.7 + index
		local length = 8 + (branch + index) % 5
		local branchPart = part("Branch", Vector3.new(length, 1.2, 1.2), position + Vector3.new(math.cos(angle) * 3.5, height * (0.58 + branch * 0.07), math.sin(angle) * 3.5), Color3.fromRGB(58, 42, 31), root, Enum.Material.Wood)
		branchPart.Shape = Enum.PartType.Cylinder
		branchPart.CFrame = CFrame.lookAt(branchPart.Position, branchPart.Position + Vector3.new(math.cos(angle), 0.45, math.sin(angle))) * CFrame.Angles(0, math.rad(90), 0)
	end
	local leafColor = Color3.fromRGB(28 + index % 9, 54 + index % 15, 35 + index % 7)
	for crown = 1, 7 do
		local angle = crown * 2.1 + index * 0.7
		local radius = crown == 1 and 0 or 6 + crown % 3
		local foliage = part("Foliage", Vector3.new(11 + crown % 5, 10 + (crown * 2) % 6, 11 + (crown + 2) % 5), position + Vector3.new(math.cos(angle) * radius, height - 1 + (crown % 3) * 4, math.sin(angle) * radius), leafColor, root, Enum.Material.Grass)
		foliage.Shape = Enum.PartType.Ball
		foliage.CanCollide = false
	end
end

local function applyAtmosphere()
	Lighting.ClockTime = 9
	Lighting.Ambient = Color3.fromRGB(90, 94, 100)
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.38
		atmosphere.Haze = 1.8
		atmosphere.Glare = 0.08
		atmosphere.Color = Color3.fromRGB(177, 187, 174)
		atmosphere.Decay = Color3.fromRGB(92, 104, 115)
		atmosphere.Parent = Lighting
	end
	if not Lighting:FindFirstChild("HollowGrade") then
		local color = Instance.new("ColorCorrectionEffect")
		color.Name = "HollowGrade"
		color.Saturation = -0.18
		color.Contrast = 0.08
		color.TintColor = Color3.fromRGB(224, 231, 215)
		color.Parent = Lighting
		local bloom = Instance.new("BloomEffect")
		bloom.Intensity = 0.22; bloom.Size = 32; bloom.Threshold = 1.25; bloom.Parent = Lighting
		local rays = Instance.new("SunRaysEffect")
		rays.Intensity = 0.055; rays.Spread = 0.7; rays.Parent = Lighting
	end
end

local function findMapOrigin(): Vector3
	local bestSpawn: SpawnLocation? = nil
	for _, item in workspace:GetDescendants() do
		if item:IsA("SpawnLocation") and (not bestSpawn or item.Position.Y > bestSpawn.Position.Y) then
			bestSpawn = item
		end
	end
	if bestSpawn then return bestSpawn.Position end
	for _, item in workspace:GetDescendants() do
		if item:IsA("BasePart") and item.Anchored and item.Size.Magnitude > 8 then return item.Position end
	end
	return Vector3.zero
end

local function hasAuthoredMap(): boolean
	local modelCount, partCount = 0, 0
	for _, child in workspace:GetDescendants() do
		if child:IsA("Model") then modelCount += 1 end
		if child:IsA("BasePart") and child.Name ~= "Baseplate" and not child:IsA("SpawnLocation") then partCount += 1 end
	end
	return modelCount >= 5 or partCount >= 35 or workspace:GetAttribute("UseAuthoredMap") == true
end

local function setDoorCollision(doorInstance, collidable)
	if doorInstance:IsA("BasePart") then
		doorInstance.CanCollide = collidable
	elseif doorInstance:IsA("Model") then
		for _, child in ipairs(doorInstance:GetDescendants()) do
			if child:IsA("BasePart") then
				child.CanCollide = collidable
			end
		end
	end
end

local function wireAuthoredDoors(root: Folder)
	local wired = 0
	local seen: { [BasePart]: boolean } = {}
	for _, item in workspace:GetDescendants() do
		if wired >= 40 then break end
		local candidate: BasePart? = nil
		local loweredName = string.lower(item.Name)
		if item:IsA("BasePart") and loweredName == "door" then
			candidate = item
		elseif item:IsA("Model") and loweredName == "door" then
			local hinged = item:FindFirstChildWhichIsA("HingeConstraint", true)
			if hinged and hinged.Parent and hinged.Parent:IsA("BasePart") then candidate = hinged.Parent end
			local largest = 0
			if not candidate then
				for _, child in item:GetDescendants() do
					if child:IsA("BasePart") and child.Size.Magnitude > largest then candidate = child; largest = child.Size.Magnitude end
				end
			end
		end
		if candidate and not seen[candidate] and not candidate:IsDescendantOf(root) then
			seen[candidate] = true
			candidate:SetAttribute("ClosedCFrame", candidate.CFrame)
			candidate:SetAttribute("DoorOpen", false)
			setDoorCollision(item, true)
			local doorPrompt = candidate:FindFirstChildOfClass("ProximityPrompt") or prompt(candidate, "Open", "Door", "Door")
			doorPrompt.ActionText = "Open"
			doorPrompt.ObjectText = "Door"
			doorPrompt.KeyboardKeyCode = Enum.KeyCode.E
			doorPrompt.GamepadKeyCode = Enum.KeyCode.ButtonX
			doorPrompt.HoldDuration = 0.15
			doorPrompt.RequiresLineOfSight = false
			doorPrompt:SetAttribute("Kind", "Door")
			if item:IsA("Model") then
				local hinge = item:FindFirstChildWhichIsA("HingeConstraint", true)
				if hinge then
					hinge:SetAttribute("ClosedAngle", hinge.CurrentAngle)
					hinge.LimitsEnabled = false
					hinge.ActuatorType = Enum.ActuatorType.Servo
					hinge.AngularSpeed = 2.2
					hinge.ServoMaxTorque = 100000
					hinge.TargetAngle = hinge.CurrentAngle
				end
				item:SetAttribute("ClosedPivot", item:GetPivot())
				local oldReference = doorPrompt:FindFirstChild("DoorModel")
				if oldReference then oldReference:Destroy() end
				local reference = Instance.new("ObjectValue")
				reference.Name = "DoorModel"
				reference.Value = item
				reference.Parent = doorPrompt
			end
			wired += 1
		end
	end
end

local function removeTemplateBaseplates(root: Folder)
	local removed = 0
	for _, item in workspace:GetDescendants() do
		if item:IsA("BasePart") and not item:IsDescendantOf(root) then
			local isNamedBaseplate = string.lower(item.Name) == "baseplate"
			local isHugeStuddedSlab = item.Anchored and item.Size.X > 150 and item.Size.Z > 150 and item.TopSurface == Enum.SurfaceType.Studs
			if isNamedBaseplate or isHugeStuddedSlab then
				item:Destroy()
				removed += 1
			end
		end
	end
end

local function groundFloatingHouses(root: Folder)
	local moved = 0
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	for _, item in workspace:GetDescendants() do
		if item:IsA("Model") and string.lower(item.Name) == "house" and not item:IsDescendantOf(root) then
			local frame, size = item:GetBoundingBox()
			if size.Magnitude > 10 and size.Magnitude < 180 then
				local result = workspace:Raycast(frame.Position + Vector3.new(0, 100, 0), Vector3.new(0, -300, 0), params)
				if result then
					local bottom = frame.Position.Y - size.Y / 2
					local gap = bottom - result.Position.Y
					if gap > 2 and gap < 80 then
						item:PivotTo(item:GetPivot() - Vector3.new(0, gap, 0))
						moved += 1
					end
				end
			end
		end
	end
end

local function secureAuthoredWindows(root: Folder)
	local secured = 0
	for _, item in workspace:GetDescendants() do
		if item:IsA("BasePart") and not item:IsDescendantOf(root) then
			local name = string.lower(item.Name)
			if string.find(name, "window", 1, true) or string.find(name, "glass", 1, true) then
				item.CanCollide = true
				item.CanTouch = true
				secured += 1
			end
		elseif item:IsA("Model") and not item:IsDescendantOf(root) and string.find(string.lower(item.Name), "window", 1, true) then
			local frame, size = item:GetBoundingBox()
			if size.Magnitude < 30 and size.X > 1 and size.Y > 1 then
				local barrier = Instance.new("Part")
				barrier.Name = "WindowBarrier"
				barrier.Size = Vector3.new(math.max(0.35, size.X), math.max(0.35, size.Y), math.max(0.35, math.min(size.Z, 0.8)))
				barrier.CFrame = frame
				barrier.Transparency = 1
				barrier.Anchored = true
				barrier.CanCollide = true
				barrier.CanTouch = true
				barrier.Parent = root
				secured += 1
			end
		end
	end
end

local function addAuthoredGameplay(root: Folder, config)
	removeTemplateBaseplates(root)
	groundFloatingHouses(root)
	local origin = findMapOrigin()
	root:SetAttribute("AuthoredMap", true)
	root:SetAttribute("MapOrigin", origin)
	for _, item in workspace:GetDescendants() do
		if item:IsA("SpawnLocation") and item.Position.Y < origin.Y - 5 then
			item.Enabled = false
		end
	end
	wireAuthoredDoors(root)
	secureAuthoredWindows(root)
	for i, position in ipairs(config.SupplySpawns or {}) do
		local cratePosition = findSupplyGround(position)
		local crate = part(`Searchable{i}`, Vector3.new(3, 2, 3), cratePosition, Color3.fromRGB(85, 65, 43), root)
		crate:SetAttribute("Looted", false)
		local highlight = Instance.new("Highlight")
		highlight.FillColor = Color3.fromRGB(214, 172, 77)
		highlight.FillTransparency = 0.78
		highlight.OutlineTransparency = 0.3
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Parent = crate
		prompt(crate, "Search", "Abandoned supplies", "Loot")
	end
	local nearbyHouses = {}
	for _, item in workspace:GetDescendants() do
		if item:IsA("Model") and string.lower(item.Name) == "house" and not item:IsDescendantOf(root) then
			local frame, size = item:GetBoundingBox()
			if size.Magnitude > 10 and size.Magnitude < 180 then table.insert(nearbyHouses, { model = item, frame = frame, size = size }) end
		end
	end
	table.sort(nearbyHouses, function(a, b) return (a.frame.Position - origin).Magnitude < (b.frame.Position - origin).Magnitude end)
	for i = 1, math.min(6, #nearbyHouses) do
		local house = nearbyHouses[i]
		local floorPosition = Vector3.new(house.frame.Position.X, house.frame.Position.Y - house.size.Y / 2 + 1.1, house.frame.Position.Z)
		local crate = part(`HouseSupply{i}`, Vector3.new(2.5, 1.8, 2.5), floorPosition, Color3.fromRGB(105, 76, 43), root)
		crate:SetAttribute("Looted", false)
		local highlight = Instance.new("Highlight")
		highlight.FillColor = Color3.fromRGB(235, 188, 82); highlight.FillTransparency = 0.7; highlight.OutlineTransparency = 0.15; highlight.DepthMode = Enum.HighlightDepthMode.Occluded; highlight.Parent = crate
		prompt(crate, "Search", "Household supplies", "Loot")
	end
	local workbenchPos = Vector3.new(-43.599, 14.193, 43.145)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {}
	local shortSurface = workspace:Raycast(workbenchPos + Vector3.new(0, 3, 0), Vector3.new(0, -15, 0), rayParams)
	local surface = shortSurface or workspace:Raycast(workbenchPos + Vector3.new(0, 50, 0), Vector3.new(0, -100, 0), rayParams)
	local workbenchY = surface and surface.Position.Y or workbenchPos.Y
	local workbench = part("Workbench", Vector3.new(6, 3, 3), Vector3.new(workbenchPos.X, workbenchY + 1.5, workbenchPos.Z), Color3.fromRGB(69, 48, 33), root)
	prompt(workbench, "Craft", "Village workbench", "Craft")
	local hatch = part("OldHatch", Vector3.new(8, 0.7, 8), origin + Vector3.new(65, 1, -55), Color3.fromRGB(28, 28, 30), root, Enum.Material.Metal)
	prompt(hatch, "Investigate", "Buried signal hatch", "Clue")
end

local function building(root: Folder, name: string, center: Vector3, color: Color3)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = root
	part("Floor", Vector3.new(34, 1, 26), center, color, model)
	part("Roof", Vector3.new(34, 1, 26), center + Vector3.new(0, 13, 0), Color3.fromRGB(38, 38, 43), model)
	part("Back", Vector3.new(34, 13, 1), center + Vector3.new(0, 6.5, -12.5), color, model)
	part("Left", Vector3.new(1, 13, 26), center + Vector3.new(-16.5, 6.5, 0), color, model)
	part("Right", Vector3.new(1, 13, 26), center + Vector3.new(16.5, 6.5, 0), color, model)
	part("FrontL", Vector3.new(13, 13, 1), center + Vector3.new(-10.5, 6.5, 12.5), color, model)
	part("FrontR", Vector3.new(13, 13, 1), center + Vector3.new(10.5, 6.5, 12.5), color, model)
	part("Porch", Vector3.new(34, 0.7, 6), center + Vector3.new(0, 0.15, 15.5), Color3.fromRGB(79, 61, 45), model)
	for x = -15, 15, 10 do
		part("PorchPost", Vector3.new(0.7, 9, 0.7), center + Vector3.new(x, 4.5, 17.5), Color3.fromRGB(70, 55, 43), model)
	end
	part("PorchRoof", Vector3.new(35, 0.6, 7), center + Vector3.new(0, 9, 15.5), Color3.fromRGB(45, 43, 42), model, Enum.Material.Slate)
	local door = part("Door", Vector3.new(5, 9, 0.7), center + Vector3.new(0, 4.5, 12.7), Color3.fromRGB(52, 43, 37), model)
	part("Handle", Vector3.new(0.35, 0.35, 0.35), door.Position + Vector3.new(1.7, 0, 0.5), Color3.fromRGB(205, 164, 74), model, Enum.Material.Metal).Shape = Enum.PartType.Ball
	window(model, center + Vector3.new(-10, 6.2, 12.7), Vector3.new(5.5, 4, 0.25))
	window(model, center + Vector3.new(10, 6.2, 12.7), Vector3.new(5.5, 4, 0.25))
	local sign = part("NameSign", Vector3.new(12, 2.2, 0.35), center + Vector3.new(0, 10.5, 12.9), Color3.fromRGB(63, 51, 39), model)
	surfaceText(sign, string.upper(name), Enum.NormalId.Back, Color3.fromRGB(231, 218, 183))
	part("Table", Vector3.new(5, 0.5, 3), center + Vector3.new(7, 3, 0), Color3.fromRGB(72, 52, 36), model)
	for _, offset in ipairs({ Vector3.new(5,1.5,0), Vector3.new(9,1.5,0) }) do
		part("Chair", Vector3.new(1.8, 3, 1.8), center + offset, Color3.fromRGB(60, 46, 35), model)
	end
end

function WorldService:Init(registry)
	self.Registry = registry
end

function WorldService:Start()
	if workspace:FindFirstChild("HollowSignalWorld") then return end
	local authored = hasAuthoredMap()
	if authored then
		local authoredRoot = Instance.new("Folder")
		authoredRoot.Name = "HollowSignalWorld"
		authoredRoot.Parent = workspace
		addAuthoredGameplay(authoredRoot, self.Registry.Config)
		applyAtmosphere()
		return
	end
	for _, oldName in ipairs({ "Baseplate", "SpawnLocation" }) do
		local old = workspace:FindFirstChild(oldName)
		if old then old:Destroy() end
	end
	local root = Instance.new("Folder")
	root.Name = "HollowSignalWorld"
	root.Parent = workspace
	root:SetAttribute("MapOrigin", Vector3.zero)

	part("Ground", Vector3.new(650, 2, 650), Vector3.new(0, -2, 0), Color3.fromRGB(44, 58, 42), root, Enum.Material.Ground)
	part("Road", Vector3.new(30, 0.4, 540), Vector3.new(0, 0, 0), Color3.fromRGB(47, 48, 53), root, Enum.Material.Concrete)
	part("CrossRoad", Vector3.new(180, 0.4, 26), Vector3.new(0, 0, -15), Color3.fromRGB(47, 48, 53), root, Enum.Material.Concrete)
	part("SidewalkL", Vector3.new(7, 0.5, 540), Vector3.new(-19, 0.15, 0), Color3.fromRGB(102, 101, 94), root, Enum.Material.Concrete)
	part("SidewalkR", Vector3.new(7, 0.5, 540), Vector3.new(19, 0.15, 0), Color3.fromRGB(102, 101, 94), root, Enum.Material.Concrete)
	building(root, "Communal Shelter", Vector3.new(-55, 0, -60), Color3.fromRGB(91, 78, 68))
	building(root, "Clinic", Vector3.new(55, 0, -60), Color3.fromRGB(111, 121, 115))
	building(root, "Workshop", Vector3.new(-55, 0, 30), Color3.fromRGB(115, 91, 67))
	building(root, "Diner", Vector3.new(55, 0, 30), Color3.fromRGB(108, 82, 80))
	for i, pos in ipairs({ Vector3.new(-75,0,110), Vector3.new(70,0,115), Vector3.new(-65,0,190), Vector3.new(65,0,195), Vector3.new(-70,0,-155), Vector3.new(72,0,-165) }) do
		building(root, `House {i}`, pos, Color3.fromRGB(83 + i * 4, 78, 73))
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "TownSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = Vector3.new(0, 1, -30)
	spawn.Neutral = true
	spawn.Transparency = 0.4
	spawn.Parent = root

	local workbench = part("Workbench", Vector3.new(6, 3, 3), Vector3.new(-55, 2, 30), Color3.fromRGB(69, 48, 33), root)
	prompt(workbench, "Craft", "Workshop bench", "Craft")
	for i = 1, 52 do
		local angle = i * math.pi * 2 / 52
		local radius = 245 + (i % 4) * 16
		organicTree(root, i, Vector3.new(math.cos(angle) * radius, -1, math.sin(angle) * radius))
	end
	for i = 1, 9 do
		local z = -220 + i * 48
		local pole = part(`Streetlight{i}`, Vector3.new(0.7, 16, 0.7), Vector3.new(i % 2 == 0 and -25 or 25, 8, z), Color3.fromRGB(43, 44, 47), root, Enum.Material.Metal)
		local lamp = part("Lamp", Vector3.new(2.5, 1.2, 2.5), pole.Position + Vector3.new(0, 8, 0), Color3.fromRGB(255, 196, 112), root, Enum.Material.Glass)
		local light = Instance.new("PointLight")
		light.Range = 28; light.Brightness = 1.8; light.Color = Color3.fromRGB(255, 187, 97); light.Enabled = false; light.Parent = lamp
		CollectionService:AddTag(light, "NightLight")
	end
	for i = 1, 30 do
		local x = ((i * 83) % 420) - 210
		local z = ((i * 47) % 470) - 235
		if math.abs(x) > 35 then
			local grass = part(`WildGrass{i}`, Vector3.new(2 + i % 3, 2 + i % 4, 2 + i % 3), Vector3.new(x, 0, z), Color3.fromRGB(53, 72 + i % 18, 47), root, Enum.Material.Grass)
			grass.CanCollide = false
		end
	end
	for i = 1, 18 do
		local crate = part(`Searchable{i}`, Vector3.new(3, 2, 3), Vector3.new(((i * 37) % 140) - 70, 1, ((i * 71) % 400) - 200), Color3.fromRGB(85, 65, 43), root)
		crate:SetAttribute("Looted", false)
		prompt(crate, "Search", "Supply cache", "Loot")
	end

	local hatch = part("OldHatch", Vector3.new(8, 0.7, 8), Vector3.new(0, 0, 245), Color3.fromRGB(28, 28, 30), root, Enum.Material.Metal)
	prompt(hatch, "Investigate", "Sealed hatch", "Clue")

	applyAtmosphere()
end

return WorldService
