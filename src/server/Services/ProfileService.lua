--!strict
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

local ProfileService = { Profiles = {} }
local store: any = nil

local function defaultProfile(config)
	return {
		version = config.ProfileVersion,
		xp = 0,
		inventory = { Scrap = 2, Cloth = 1 },
		journal = {},
		cosmetics = {},
		settings = { reducedShake = false, reducedHorror = false, subtitles = true },
		convenience = { outfitSlots = 2 },
		stats = { nights = 0, rescues = 0 },
	}
end

function ProfileService:Init(registry)
	self.Registry = registry
	self.Config = registry.Config
	-- GetDataStore throws for an unpublished place. Persistence must degrade to
	-- session-only play instead of preventing the entire server from starting.
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("HollowSignalProfiles_v1")
	end)
	if ok then
		store = result
	else
		warn("Persistence unavailable; using session-only profiles:", result)
	end
end

function ProfileService:Load(player: Player)
	local profile = defaultProfile(self.Config)
	if not store then
		player:SetAttribute("PersistenceUnavailable", true)
		profile.session = HttpService:GenerateGUID(false)
		self.Profiles[player] = profile
		return profile
	end
	local ok, data = pcall(function() return store:GetAsync(`p_{player.UserId}`) end)
	if ok and type(data) == "table" then
		for key, value in data do profile[key] = value end
	elseif not ok then
		player:SetAttribute("PersistenceUnavailable", true)
		warn("Profile load failed", player.UserId, data)
	end
	profile.session = HttpService:GenerateGUID(false)
	self.Profiles[player] = profile
	return profile
end

function ProfileService:Save(player: Player)
	local profile = self.Profiles[player]
	if not store or not profile or player:GetAttribute("PersistenceUnavailable") then return end
	local copy = table.clone(profile)
	copy.session = nil
	local ok, err = pcall(function()
		store:UpdateAsync(`p_{player.UserId}`, function() return copy end)
	end)
	if not ok then warn("Profile save failed", player.UserId, err) end
end

function ProfileService:Get(player: Player)
	local profile = self.Profiles[player]
	if not profile and player.Parent == Players then
		profile = self:Load(player)
	end
	return profile
end

function ProfileService:Start()
	Players.PlayerAdded:Connect(function(player)
		if not self.Profiles[player] then self:Load(player) end
	end)
	Players.PlayerRemoving:Connect(function(player) self:Save(player); self.Profiles[player] = nil end)
	for _, player in Players:GetPlayers() do self:Load(player) end
	task.spawn(function()
		while task.wait(self.Config.AutosaveSeconds) do
			for _, player in Players:GetPlayers() do self:Save(player) end
		end
	end)
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do task.spawn(function() self:Save(player) end) end
		task.wait(2)
	end)
end

return ProfileService
