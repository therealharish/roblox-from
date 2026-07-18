-- Rebuild the Ancient Passage Tree in Studio (avoids module caching issues)
-- Paste into the Studio Command Bar and press Enter.

local old = workspace:FindFirstChild("Ancient Passage Tree")
if old then
	old:Destroy()
end

local source = game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("AncientPassageTree")
local temp = source:Clone()
temp.Parent = workspace

local Tree = require(temp)
Tree.Build({
	Origin = CFrame.new(),
	Seed = 1749,
})

temp:Destroy()

print("Ancient Passage Tree rebuilt.")
