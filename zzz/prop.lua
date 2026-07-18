local HttpService = game:GetService("HttpService")

local model =game.ServerStorage["Info NPCs"]["NPC Info Guy"]
local data = {}

for _, obj in ipairs(model:GetDescendants()) do
	if obj:IsA("BasePart") then
		table.insert(data, {
			Name = obj.Name,
			Path = obj:GetFullName(),
			Size = {
				obj.Size.X,
				obj.Size.Y,
				obj.Size.Z
			},
			Position = {
				obj.Position.X,
				obj.Position.Y,
				obj.Position.Z
			},
			Color = obj.Color:ToHex(),
			Material = tostring(obj.Material),
			Transparency = obj.Transparency,
			Anchored = obj.Anchored,
			CanCollide = obj.CanCollide,
		})
	end
end

print(HttpService:JSONEncode(data))