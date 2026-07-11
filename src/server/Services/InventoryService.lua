--!strict
local InventoryService = {}

function InventoryService:Init(registry) self.Registry = registry end
function InventoryService:Get(player)
	local profile = self.Registry.ProfileService:Get(player)
	return profile and profile.inventory or {}
end
function InventoryService:Add(player, item, amount)
	if not self.Registry.Config.Items[item] then return false end
	local inv = self:Get(player)
	local count = 0
	for _, qty in inv do count += qty end
	if count + amount > self.Registry.Config.InventoryCapacity then return false end
	inv[item] = (inv[item] or 0) + amount
	return true
end
function InventoryService:Consume(player, item, amount)
	local inv = self:Get(player)
	if (inv[item] or 0) < amount then return false end
	inv[item] -= amount
	if inv[item] <= 0 then inv[item] = nil end
	return true
end
function InventoryService:Craft(player, recipe)
	local costs = self.Registry.Config.Recipes[recipe]
	if not costs then return false, "Unknown recipe" end
	local inv = self:Get(player)
	for item, amount in costs do if (inv[item] or 0) < amount then return false, `Need {amount} {item}` end end
	for item, amount in costs do self:Consume(player, item, amount) end
	self:Add(player, recipe, 1)
	return true, `Crafted {recipe}`
end
return InventoryService
