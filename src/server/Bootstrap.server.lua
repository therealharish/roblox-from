--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(shared:WaitForChild("Config"))
local Protocol = require(shared:WaitForChild("Protocol"))

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage
for _, name in { Protocol.Action, Protocol.State, Protocol.Toast } do
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotes
end

local services = script.Parent:WaitForChild("Services")
local order = {
	"WorldService",
	"ProfileService",
	"ShelterService",
	"InventoryService",
	"QuestService",
	"ConditionService",
	"CreatureService",
	"CycleService",
	"InteractionService",
}

local registry: { [string]: any } = {
	Config = Config,
	Protocol = Protocol,
	Remotes = remotes,
}
for _, name in order do
	registry[name] = require(services:WaitForChild(name))
end
for _, name in order do
	local service = registry[name]
	if service.Init then service:Init(registry) end
end
-- The interaction service discovers prompts created by the world, so world
-- construction is the one deliberately synchronous startup step.
registry.WorldService:Start()
for _, name in order do
	if name ~= "WorldService" then
		local service = registry[name]
		if service.Start then task.spawn(function() service:Start() end) end
	end
end

print(`[Hollow Signal] Server started with {#order} services`)
