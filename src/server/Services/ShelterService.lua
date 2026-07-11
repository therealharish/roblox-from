--!strict
local CollectionService = game:GetService("CollectionService")
local ShelterService = {}
function ShelterService:Init(registry) self.Registry = registry end
function ShelterService:IsSafe(position: Vector3)
	for _, zone in CollectionService:GetTagged("SafeZone") do
		local localPos = zone.CFrame:PointToObjectSpace(position)
		local half = zone.Size / 2
		if math.abs(localPos.X) <= half.X and math.abs(localPos.Y) <= half.Y and math.abs(localPos.Z) <= half.Z then
			local ward = zone.Parent and zone.Parent:FindFirstChild("Ward")
			return ward ~= nil and (ward:GetAttribute("Integrity") or 0) > 0
		end
	end
	return false
end
function ShelterService:Repair(player: Player, ward: BasePart)
	if not CollectionService:HasTag(ward, "Ward") then return false, "Invalid ward" end
	if not self.Registry.InventoryService:Consume(player, "Scrap", 1) then return false, "Need Scrap" end
	ward:SetAttribute("Integrity", math.min(100, (ward:GetAttribute("Integrity") or 0) + 25))
	return true, "Ward repaired"
end
return ShelterService
