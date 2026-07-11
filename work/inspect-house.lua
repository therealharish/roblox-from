local path = ...
local roots = fs.read(path, "rbxm")

local function walk(item, depth)
	local lower = string.lower(item.Name)
	local interesting = string.find(lower, "door", 1, true)
		or string.find(lower, "window", 1, true)
		or string.find(lower, "glass", 1, true)
	if interesting or depth <= 2 then
		print(string.rep("  ", depth) .. item.ClassName .. " :: " .. item.Name)
	end
	for _, child in ipairs(item:GetChildren()) do
		walk(child, depth + 1)
	end
end

local function describe(item, depth)
	local suffix = ""
	if item:IsA("BasePart") then suffix = string.format(" size=(%.2f,%.2f,%.2f)", item.Size.X, item.Size.Y, item.Size.Z) end
	print(string.rep("  ", depth) .. item.ClassName .. " :: " .. item.Name .. suffix)
	for _, child in ipairs(item:GetChildren()) do describe(child, depth + 1) end
end

if typeof(roots) == "Instance" then
	walk(roots, 0)
	for _, item in ipairs(roots:GetDescendants()) do
		if item:IsA("Model") and string.lower(item.Name) == "door" then print("\nDOOR DETAIL"); describe(item, 0) end
	end
else
	for _, root in ipairs(roots) do walk(root, 0) end
end
