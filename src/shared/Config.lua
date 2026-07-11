--!strict
return table.freeze({
	GameName = "Hollow Signal",
	ProfileVersion = 1,
	MaxPlayers = 8,
	Cycle = {
		Day = 600,
		Warning = 120,
		Siege = 600,
		Dawn = 60,
	},
	StudioCycleScale = 0.1,
	Player = {
		MaxCondition = 100,
		DownedSeconds = 45,
		ReviveSeconds = 5,
	},
	Creature = {
		MinCount = 2,
		PerPlayer = 2,
		MaxCount = 8,
		WalkSpeed = 10,
		ChaseSpeed = 17,
		DetectionRadius = 160,
		AttackRange = 5,
		AttackDamage = 35,
		AttackCooldown = 2,
		StaggerSeconds = 2.5,
	},
	InventoryCapacity = 12,
	AutosaveSeconds = 60,
	RemoteRatePerSecond = 8,
	Audio = {
		-- Upload outputs/hollow_signal_ambient.wav to Creator Hub and paste the
		-- resulting asset id here as "rbxassetid://123456789".
		AmbientMusicId = "rbxassetid://119485757837366",
		MusicVolume = 0.32,
		WarningScreechId = "rbxassetid://88369188026590",
		AttackStingId = "rbxassetid://89011060784735",
	},
	Items = {
		Scrap = { display = "Scrap", stack = 8 },
		Cloth = { display = "Cloth", stack = 8 },
		Medicine = { display = "Medicine", stack = 3 },
		Bandage = { display = "Bandage", stack = 3 },
		Flare = { display = "Flare", stack = 3 },
		Noisemaker = { display = "Noisemaker", stack = 3 },
		Plank = { display = "Plank", stack = 4 },
	},
	Recipes = {
		Flare = { Scrap = 1, Cloth = 1 },
		Noisemaker = { Scrap = 2 },
		Plank = { Scrap = 2 },
		Bandage = { Cloth = 2 },
	},
})
