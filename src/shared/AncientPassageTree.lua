-- AncientPassageTree.lua
-- Roblox Studio component: a large, leafless tree with a walkable trunk passage.
-- Put this ModuleScript in ReplicatedStorage, then require it from the Command Bar
-- or a server Script. See AncientPassageTree_README.md for examples.
local Tree = {}

local DEFAULTS = {
	Name = "Ancient Passage Tree",
	Origin = CFrame.new(0, 0, 0),
	Seed = 1749,
	Scale = 1.15,
	PassageWidth = 6,
	PassageHeight = 12,
	PassageDepth = 5,
	Bottles = true,
	BottleCount = 14,
	Detail = 1.2, -- 0.5 to 1.5 is sensible
}

local BARK = Color3.fromRGB(82, 62, 46)
local DARK_BARK = Color3.fromRGB(52, 39, 30)
local INNER_WOOD = Color3.fromRGB(76, 51, 34)
local ROOT_COLOR = Color3.fromRGB(68, 51, 39)
local BOTTLE_COLORS = {
	Color3.fromRGB(35, 110, 45),
	Color3.fromRGB(30, 80, 150),
	Color3.fromRGB(160, 35, 35),
	Color3.fromRGB(180, 120, 25),
	Color3.fromRGB(120, 45, 140),
	Color3.fromRGB(170, 170, 170),
}

local function merge(defaults, supplied)
	local result = table.clone(defaults)
	for key, value in pairs(supplied or {}) do
		result[key] = value
	end
	return result
end

local function smoothPart(parent, name, size, cf, color, material, collide)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = material or Enum.Material.Wood
	part.Anchored = true
	part.CanCollide = collide ~= false
	part.CanQuery = true
	part.CanTouch = collide ~= false
	part.CastShadow = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Roblox cylinders run along local X. This aligns one precisely between two points.
local function cylinderBetween(parent, name, a, b, radiusA, radiusB, color, material, collide)
	local delta = b - a
	local length = delta.Magnitude
	if length < 0.05 then return nil end

	local midpoint = (a + b) * 0.5
	local direction = delta.Unit
	local up = math.abs(direction:Dot(Vector3.yAxis)) > 0.98 and Vector3.zAxis or Vector3.yAxis
	local cf = CFrame.lookAt(midpoint, midpoint + direction, up) * CFrame.Angles(0, math.pi / 2, 0)

	-- Each successive segment has a smaller radius, creating a stable tapered chain
	-- without runtime CSG or custom asset dependencies.
	local radius = (radiusA + radiusB) * 0.5
	local part = smoothPart(parent, name, Vector3.new(length, radius * 2, radius * 2), cf, color, material, collide)
	part.Shape = Enum.PartType.Cylinder
	return part
end

local function vec(point)
	if typeof(point) == "Vector3" then return point end
	return Vector3.new(point[1], point[2], point[3])
end

local function localPoint(origin, scale, point)
	return origin:PointToWorldSpace(vec(point) * scale)
end

local function addBarkRidges(parent, rng, a, b, radius, count, scale)
	local axis = b - a
	local length = axis.Magnitude
	for _ = 1, count do
		local t1 = rng:NextNumber(0.03, 0.78)
		local ridgeLength = rng:NextNumber(0.16, 0.34)
		local t2 = math.min(0.98, t1 + ridgeLength)
		local side = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))
		if side.Magnitude < 0.1 then side = Vector3.xAxis end
		side = side.Unit * radius * rng:NextNumber(0.80, 1.02)
		local p1 = a + axis * t1 + side
		local p2 = a + axis * t2 + side * rng:NextNumber(0.75, 1.05)
		cylinderBetween(parent, "Bark Ridge", p1, p2, rng:NextNumber(0.08, 0.16) * scale,
			0.05 * scale, DARK_BARK, Enum.Material.Wood, false)
	end
end

local function addBranch(parent, details, rng, origin, scale, points, startRadius, endRadius)
	for index = 1, #points - 1 do
		local a = localPoint(origin, scale, points[index])
		local b = localPoint(origin, scale, points[index + 1])
		local alpha = (index - 1) / math.max(1, #points - 2)
		local nextAlpha = index / math.max(1, #points - 2)
		local r1 = startRadius + (endRadius - startRadius) * alpha
		local r2 = startRadius + (endRadius - startRadius) * nextAlpha
		cylinderBetween(parent, "Branch", a, b, r1 * scale, r2 * scale, BARK, Enum.Material.Wood, true)
		if r1 > 0.55 then
			addBarkRidges(details, rng, a, b, r1 * scale, math.max(1, math.floor(r1 * 1.3)), scale)
		end
	end
end

local function addBottle(parent, attachmentPoint, length, rng, scale)
	local model = Instance.new("Model")
	model.Name = "Hanging Bottle"
	model.Parent = parent

	local cordLength = length * scale
	local cord = cylinderBetween(model, "Cord", attachmentPoint, attachmentPoint - Vector3.new(0, cordLength, 0),
		0.035 * scale, 0.035 * scale, Color3.fromRGB(29, 25, 21), Enum.Material.Fabric, false)
	if cord then cord.CanQuery = false end

	local bottom = attachmentPoint - Vector3.new(0, cordLength, 0)
	local color = BOTTLE_COLORS[rng:NextInteger(1, #BOTTLE_COLORS)]
	local bottleHeight = rng:NextNumber(1.7, 2.6) * scale
	local bodyRadius = 0.28 * scale

	-- Body: tall vertical cylinder. Size.X is the cylinder axis (height), Y/Z are diameter.
	local bodyHalfHeight = bottleHeight * 0.37
	local bodyCf = CFrame.new(bottom - Vector3.new(0, bodyHalfHeight, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	local body = smoothPart(model, "Bottle", Vector3.new(bodyHalfHeight * 2, bodyRadius * 2, bodyRadius * 2),
		bodyCf, color, Enum.Material.Glass, false)
	body.Shape = Enum.PartType.Cylinder
	body.Transparency = 0.18
	body.Reflectance = 0.05

	-- Rounded bottle base overlapping the body bottom.
	local baseBall = smoothPart(model, "Bottle Base", Vector3.new(bodyRadius * 2.2, bodyRadius * 2.2, bodyRadius * 2.2),
		CFrame.new(bottom - Vector3.new(0, bodyHalfHeight * 2 - bodyRadius * 0.2, 0)), color, Enum.Material.Glass, false)
	baseBall.Shape = Enum.PartType.Ball
	baseBall.Transparency = 0.15

	-- Neck: thin vertical cylinder sitting on top of the body.
	local neckHeight = 0.55 * scale
	local neckRadius = 0.12 * scale
	local neckCf = CFrame.new(bottom + Vector3.new(0, neckHeight * 0.5, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	local neck = smoothPart(model, "Neck", Vector3.new(neckHeight, neckRadius * 2, neckRadius * 2),
		neckCf, color, Enum.Material.Glass, false)
	neck.Shape = Enum.PartType.Cylinder
	neck.Transparency = 0.14

	-- Cork: small vertical cylinder on top of the neck.
	local cork = smoothPart(model, "Cork", Vector3.new(0.18 * scale, neckRadius * 1.9, neckRadius * 1.9),
		CFrame.new(bottom + Vector3.new(0, neckHeight + 0.01 * scale, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(120, 88, 52), Enum.Material.Wood, false)
	cork.Shape = Enum.PartType.Cylinder

	local light = Instance.new("PointLight")
	light.Name = "Faint Glow"
	light.Color = Color3.fromRGB(157, 132, 78)
	light.Brightness = 0.12
	light.Range = 4 * scale
	light.Enabled = rng:NextNumber() < 0.35
	light.Parent = body

	return model
end

function Tree.Build(options)
	local cfg = merge(DEFAULTS, options)
	local rng = Random.new(cfg.Seed)
	local scale = cfg.Scale
	local origin = cfg.Origin

	local model = Instance.new("Model")
	model.Name = cfg.Name
	model:SetAttribute("GeneratedTree", true)
	model:SetAttribute("Seed", cfg.Seed)

	local structure = Instance.new("Folder")
	structure.Name = "Structure"
	structure.Parent = model
	local details = Instance.new("Folder")
	details.Name = "Bark Details"
	details.Parent = model
	local props = Instance.new("Folder")
	props.Name = "Hanging Bottles"
	props.Parent = model

	-- Buttressed roots radiate from the base and make the silhouette feel old/heavy.
	for i = 1, 16 do
		local angle = (i / 16) * math.pi * 2 + rng:NextNumber(-0.18, 0.18)
		local length = rng:NextNumber(6, 11)
		local width = rng:NextNumber(0.7, 1.5)
		local start = localPoint(origin, scale, Vector3.new(math.cos(angle) * 3.0, 1.0, math.sin(angle) * 3.0))
		local finish = localPoint(origin, scale, Vector3.new(math.cos(angle) * length, rng:NextNumber(0.15, 0.5), math.sin(angle) * length))
		cylinderBetween(structure, "Root", start, finish, width * scale, 0.22 * scale, ROOT_COLOR, Enum.Material.Wood, true)
	end

	-- Big gnarled trunk with a large oval hollow in the front face.
	local pw = cfg.PassageWidth
	local ph = cfg.PassageHeight
	local pd = cfg.PassageDepth
	local trunkRadius = 5.0
	local trunkHeight = 24
	local holeOpenAngle = math.rad(165)
	local segmentCount = 14

	-- Central core so branches have something to grow from and the trunk feels solid.
	local coreBase = localPoint(origin, scale, Vector3.new(0, 0, 0))
	local coreTop = localPoint(origin, scale, Vector3.new(0, trunkHeight * 0.78, 0))
	cylinderBetween(structure, "Trunk Core", coreBase, coreTop, trunkRadius * 0.55 * scale, trunkRadius * 0.42 * scale, BARK, Enum.Material.Wood, true)

	-- Thick outer segments forming the trunk ring; the gap in front is the hollow.
	for i = 1, segmentCount do
		local angle = -math.pi + holeOpenAngle * 0.5 + (i / (segmentCount + 1)) * (2 * math.pi - holeOpenAngle)
		local x = math.cos(angle) * trunkRadius
		local z = math.sin(angle) * trunkRadius
		local r = trunkRadius * rng:NextNumber(0.48, 0.7)
		local h = trunkHeight * rng:NextNumber(0.9, 1.05)
		local tiltOut = rng:NextNumber(-0.06, 0.06)
		local base = localPoint(origin, scale, Vector3.new(x, 0, z))
		local top = localPoint(origin, scale, Vector3.new(x * (0.9 + tiltOut), h, z * (0.9 + tiltOut)))
		cylinderBetween(structure, "Trunk Segment", base, top, r * scale, r * 0.8 * scale, BARK, Enum.Material.Wood, true)
	end

	-- Extra gnarled bulges for an organic silhouette.
	for _ = 1, 8 do
		local angle = -math.pi + holeOpenAngle * 0.5 + rng:NextNumber(0, 2 * math.pi - holeOpenAngle)
		local dist = trunkRadius * rng:NextNumber(0.55, 0.98)
		local x = math.cos(angle) * dist
		local z = math.sin(angle) * dist
		local r = trunkRadius * rng:NextNumber(0.32, 0.52)
		local h = trunkHeight * rng:NextNumber(0.35, 0.65)
		local yStart = rng:NextNumber(2, trunkHeight * 0.55)
		local base = localPoint(origin, scale, Vector3.new(x, yStart, z))
		local top = localPoint(origin, scale, Vector3.new(x, yStart + h, z))
		cylinderBetween(structure, "Trunk Bulge", base, top, r * scale, r * 0.85 * scale, DARK_BARK, Enum.Material.Wood, true)
	end

	-- Shorter oval hollow: from near the roots to just above mid-trunk.
	local holeHeight = trunkHeight * 0.58
	local holeCenterY = holeHeight * 0.5 + 1.0
	local holeWidth = trunkRadius * 1.75
	local cavityDepth = trunkRadius * 0.85

	-- Dark backing as a tall cylinder so the front silhouette reads as an oval.
	local cavityCf = origin * CFrame.new(0, holeCenterY * scale, -cavityDepth * 0.1 * scale) * CFrame.Angles(0, 0, math.pi / 2)
	local cavity = smoothPart(structure, "Inner Cavity",
		Vector3.new(cavityDepth * 0.65, holeHeight * 1.05, holeWidth) * scale,
		cavityCf, Color3.new(0.015, 0.012, 0.01), Enum.Material.Wood, false)
	cavity.Shape = Enum.PartType.Cylinder
	cavity.CastShadow = false

	-- Side panels to give the oval more horizontal width.
	for _, sideX in ipairs({-holeWidth * 0.36, holeWidth * 0.36}) do
		local side = smoothPart(structure, "Inner Cavity Side",
			Vector3.new(cavityDepth * 0.55, holeHeight * 0.92, holeWidth * 0.5) * scale,
			origin * CFrame.new(sideX * scale, holeCenterY * scale, -cavityDepth * 0.06 * scale),
			Color3.new(0.015, 0.012, 0.01), Enum.Material.Wood, false)
		side.CastShadow = false
	end

	-- Invisible trigger so gameplay scripts can detect a player entering the hollow.
	local trigger = smoothPart(structure, "TeleportTrigger",
		Vector3.new(holeWidth * 0.85, holeHeight * 0.85, cavityDepth * 0.7) * scale,
		origin * CFrame.new(0, holeCenterY * scale, 0),
		Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, false)
	trigger.Transparency = 1
	trigger.CanCollide = false
	trigger.CanTouch = true
	trigger.CanQuery = false

	-- Rough rim around the hollow so the edge reads as a torn opening.
	for _, rim in ipairs({
		{angle = -holeOpenAngle * 0.5, height = holeHeight, rMul = 0.92},
		{angle = holeOpenAngle * 0.5, height = holeHeight, rMul = 0.92},
		{angle = 0, height = holeWidth * 0.45, rMul = 0.32},
	}) do
		local r = trunkRadius * rim.rMul
		local x = math.cos(rim.angle) * r
		local z = math.sin(rim.angle) * r
		local cf = origin * CFrame.new(x * scale, holeCenterY * scale, z * scale)
		cf = cf * CFrame.Angles(0, -rim.angle, 0)
		local part = smoothPart(structure, "Hollow Rim",
			Vector3.new(trunkRadius * 0.6, rim.height, trunkRadius * 0.45) * scale,
			cf, DARK_BARK, Enum.Material.Wood, false)
		part.Transparency = 0.15
	end

	-- Major limbs are deliberately asymmetrical, like the supplied silhouette.
	local branches = {
		{{-3.8, 12, 0}, {-6, 18, 0.5}, {-10, 23, 1}, {-15, 26, 0}, {-20, 26, -1}},
		{{-1.6, 14, 0}, {-3, 21, -0.5}, {-6, 28, -1}, {-8, 35, -0.3}, {-7, 42, 0}},
		{{1.4, 14, 0}, {3, 22, 0.8}, {2.5, 30, 1}, {4, 38, 0}, {5, 45, -1}},
		{{3.8, 13, 0}, {7, 19, -0.5}, {13, 23, -1}, {20, 25, 0}, {26, 24, 1}},
		{{4, 17, 0}, {9, 25, 0.5}, {13, 33, 1}, {17, 40, 0}, {20, 46, -1}},
		{{-4, 17, 0}, {-10, 20, -1}, {-16, 21, -2}, {-23, 20, -1}, {-29, 22, 0}},
		{{2, 20, 0}, {-1, 27, 1}, {-2, 35, 2}, {-1, 43, 1}, {1, 50, 0}},
		-- Extra side branches (shorter)
		{{-5.5, 22, -0.5}, {-10, 26, -0.8}, {-15, 29, -1.0}, {-20, 31, -0.6}, {-24, 32, 0}},
		{{5.5, 22, 0.5}, {10, 26, 0.8}, {15, 29, 1.0}, {20, 31, 0.6}, {24, 32, 0}},
		{{-3.5, 26, -1}, {-8, 31, -1.5}, {-12, 35, -1.8}, {-17, 38, -1.4}, {-21, 40, -1}},
		{{3.5, 26, 1}, {8, 31, 1.5}, {12, 35, 1.8}, {17, 38, 1.4}, {21, 40, 1}},
	}

	for _, points in ipairs(branches) do
		-- Lift branch starts upward and nudge them sideways so they emerge above/around the hollow,
		-- not out of the front opening.
		local adjusted = {}
		for _, p in ipairs(points) do
			table.insert(adjusted, p)
		end
		local first = adjusted[1]
		adjusted[1] = {
			first[1] * 1.15,
			first[2] + 6.5,
			first[3] + (first[3] >= 0 and 1.8 or -1.8),
		}
		addBranch(structure, details, rng, origin, scale, adjusted, 2.8, 0.42)
	end

	-- Smaller forks. Their endpoints also become candidate hanging points.
	local twigs = {
		{{-10,23,1},{-13,31,1},{-15,38,0}}, {{-15,26,0},{-20,32,0},{-23,37,1}},
		{{-20,26,-1},{-26,28,-1},{-31,27,0}}, {{-8,35,0},{-12,42,0},{-13,48,1}},
		{{4,38,0},{2,45,0},{3,52,0}}, {{5,45,-1},{9,51,-1},{10,57,0}},
		{{13,33,1},{10,39,2},{9,46,1}}, {{17,40,0},{23,43,0},{28,42,1}},
		{{13,23,-1},{17,30,-1},{22,34,0}}, {{20,25,0},{25,30,0},{31,31,0}},
		{{-16,21,-2},{-20,17,-2},{-25,16,-1}}, {{-23,20,-1},{-29,18,0},{-34,19,1}},
		{{-2,35,2},{-7,39,2},{-10,44,1}}, {{2,30,1},{7,35,2},{11,37,1}},
		{{-1,43,1},{-4,49,1},{-3,56,0}}, {{9,25,1},{15,27,2},{19,29,1}},
	}
	for _, points in ipairs(twigs) do
		addBranch(structure, details, rng, origin, scale, points, 0.72, 0.13)
	end

	-- Short broken stubs add age and a less procedural silhouette.
	for i = 1, math.floor(22 * cfg.Detail) do
		local twig = twigs[rng:NextInteger(1, #twigs)]
		local base = vec(twig[rng:NextInteger(1, #twig - 1)])
		local direction = Vector3.new(rng:NextNumber(-4, 4), rng:NextNumber(2.5, 7), rng:NextNumber(-3, 3))
		addBranch(structure, details, rng, origin, scale, {base, base + direction}, 0.25, 0.06)
	end

	if cfg.Bottles then
		for i = 1, cfg.BottleCount do
			local twig = twigs[((i - 1) % #twigs) + 1]
			local segment = rng:NextInteger(1, #twig - 1)
			local p = vec(twig[segment]):Lerp(vec(twig[segment + 1]), rng:NextNumber(0.25, 0.85))
			addBottle(props, localPoint(origin, scale, p), rng:NextNumber(2.0, 5.5), rng, scale)
		end
	end

	-- Invisible reference marker and useful attributes for gameplay scripts.
	local pivot = smoothPart(model, "TreeCenter", Vector3.new(0.2, 0.2, 0.2),
		origin * CFrame.new(0, trunkHeight * 0.5 * scale, 0), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, false)
	pivot.Transparency = 1
	pivot.CanQuery = false
	model.PrimaryPart = pivot
	model:SetAttribute("PassageWidth", pw * scale)
	model:SetAttribute("PassageHeight", ph * scale)
	model:SetAttribute("PassageDepth", pd * scale)

	model.Parent = cfg.Parent or workspace
	return model
end

return Tree
