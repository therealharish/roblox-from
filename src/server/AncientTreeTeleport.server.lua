-- AncientTreeTeleport.server.lua
-- Teleports any player who enters the Ancient Passage Tree hollow to a random
-- ground position inside the part named "VillageZone" in Workspace.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local TELEPORT_COOLDOWN = 3 -- seconds per player
local SEARCH_RETRY_SECONDS = 5

local cooldowns = {}

local function getVillageZone()
	local zone = workspace:FindFirstChild("VillageZone")
	if zone then
		return zone
	end

	-- Create a runtime VillageZone matching the Studio placement so it survives Play mode.
	zone = Instance.new("Part")
	zone.Name = "VillageZone"
	zone.Anchored = true
	zone.CanCollide = false
	zone.Transparency = 1
	zone.CanTouch = false
	zone.CanQuery = false
	zone.Position = Vector3.new(25, 7.24, -23.5)
	zone.Size = Vector3.new(115, 988, 965)
	zone.Parent = workspace
	print("AncientTreeTeleport: created runtime VillageZone.")
	return zone
end

local function findTrigger()
	local tree = workspace:FindFirstChild("Ancient Passage Tree")
	if not tree then
		return nil
	end
	return tree:FindFirstChild("TeleportTrigger", true)
end

local function getGroundY(x, z, zone)
	local topY = zone.Position.Y + zone.Size.Y * 0.5 + 100
	local origin = Vector3.new(x, topY, z)
	local direction = Vector3.new(0, -1000, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { zone }
	local result = workspace:Raycast(origin, direction, params)
	return result and result.Position.Y or zone.Position.Y
end

local function randomPointInZone(zone)
	local pos = zone.Position
	local size = zone.Size
	local x = pos.X + (math.random() - 0.5) * size.X
	local z = pos.Z + (math.random() - 0.5) * size.Z
	local y = getGroundY(x, z, zone)
	return Vector3.new(x, y + 3, z)
end

local function teleportPlayer(player)
	local zone = getVillageZone()
	if not zone then
		warn("AncientTreeTeleport: VillageZone not found in Workspace.")
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.CFrame = CFrame.new(randomPointInZone(zone))
	end
end

local function checkTrigger(trigger)
	local parts = workspace:GetPartsInPart(trigger)
	for _, part in ipairs(parts) do
		local character = part:FindFirstAncestorOfClass("Model")
		if character then
			local player = Players:GetPlayerFromCharacter(character)
			if player then
				local now = tick()
				local last = cooldowns[player.UserId] or 0
				if now - last >= TELEPORT_COOLDOWN then
					cooldowns[player.UserId] = now
					teleportPlayer(player)
				end
			end
		end
	end
end

local function startPolling(trigger)
	RunService.Heartbeat:Connect(function()
		checkTrigger(trigger)
	end)
	print("AncientTreeTeleport: trigger polling started.")
end

local function init()
	local trigger = findTrigger()
	if trigger then
		startPolling(trigger)
		return
	end

	workspace.ChildAdded:Connect(function(child)
		if child.Name ~= "Ancient Passage Tree" then
			return
		end
		task.delay(SEARCH_RETRY_SECONDS, function()
			local newTrigger = findTrigger()
			if newTrigger then
				startPolling(newTrigger)
			end
		end)
	end)
end

init()
