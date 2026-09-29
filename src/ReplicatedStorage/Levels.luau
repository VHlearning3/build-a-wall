-- All levels. Rectangles are {xMin, xMax, zMin, zMax}. The spawn pad is at SPAWN_POSITION;
-- the orbs fly out of it towards +Z first, so the player has to bounce them back to the cores.
-- ESCAPE_POSITION is where the escape zone appears in the horror (a core position) and where
-- the Hunter has its lair (a little further away from the spawn).
-- Optional: HUNTERS (roles, default {"chaser"}), BATTERY (the flashlight runs down, pick up batteries),
-- HORROR_FOG (fog density in the horror, default 0.75).
return {
	{
		NAME = "The Grid",
		DESCRIPTION = "Bounce the orbs into the core.",
		HALF_X = 64,
		HALF_Z = 96,
		SPAWN_POSITION = Vector3.new(0, 0, 70),
		CORES = {{position = Vector3.new(0, 0, -70), hits = 5}},
		ESCAPE_POSITION = Vector3.new(0, 0, -70),
		BUDGET = 30,
		MAZE = {
			{-64, -26, 39, 41}, -- Row 1, gap on the middle-left (-26..-2)
			{-2, 64, 39, 41},
			{-64, 26, 4, 6}, -- Row 2, gap on the right (26..64)
			{-38, 64, -31, -29}, -- Row 3, gap on the left (-64..-38)
			{36, 44, 58, 66}, -- Small blocks
			{-44, -36, -58, -50},
			{-20, -12, 18, 26},
			{12, 20, -16, -8},
		},
		BUMPERS = {},
		HUNTER_LAIR_WAIT = 6,
		HUNTER_STALKS = true,
	},
	{
		NAME = "Bumper Hall",
		DESCRIPTION = "Spinning bumpers knock the orbs around. Only 20 pieces!",
		HALF_X = 64,
		HALF_Z = 96,
		SPAWN_POSITION = Vector3.new(-40, 0, 72),
		CORES = {{position = Vector3.new(40, 0, -72), hits = 5}},
		ESCAPE_POSITION = Vector3.new(40, 0, -72),
		BUDGET = 20,
		MAZE = {
			{-64, 10, 24, 26}, -- Gap on the right (10..64)
			{-10, 64, -26, -24}, -- Gap on the left (-64..-10)
			{-64, -52, -64, -52}, -- Corner blocks
			{52, 64, 52, 64},
		},
		-- Bars that spin around their centre while building; they stand still in the horror
		BUMPERS = {
			{position = Vector3.new(-24, 0, 52), length = 18, speed = 1.2},
			{position = Vector3.new(30, 0, 50), length = 16, speed = -1.6},
			{position = Vector3.new(0, 0, 0), length = 22, speed = 0.9},
			{position = Vector3.new(-34, 0, -50), length = 16, speed = -1.3},
			{position = Vector3.new(14, 0, -54), length = 14, speed = 1.8},
		},
		HUNTER_LAIR_WAIT = 6,
		HUNTER_STALKS = true,
	},
	{
		NAME = "Twin Cores",
		DESCRIPTION = "Two cores. Hit each one 3 times.",
		HALF_X = 80,
		HALF_Z = 96,
		SPAWN_POSITION = Vector3.new(0, 0, 76),
		CORES = {
			{position = Vector3.new(-50, 0, -20), hits = 3},
			{position = Vector3.new(50, 0, -76), hits = 3},
		},
		ESCAPE_POSITION = Vector3.new(50, 0, -76), -- The core furthest from the spawn
		BUDGET = 30,
		MAZE = {
			{-80, -14, 44, 46}, -- Gap in the middle-right (-14..14)
			{14, 80, 44, 46},
			{-2, 2, -96, 30}, -- Long divider down the middle, open at the top
			{-80, -30, 8, 10},
			{30, 80, -36, -34}, -- Gap on the left of the right half
			{-44, -36, -64, -56},
			{26, 34, 4, 12},
		},
		BUMPERS = {},
		HUNTER_LAIR_WAIT = 5,
		HUNTER_STALKS = true,
	},
	{
		NAME = "The Long Corridor",
		DESCRIPTION = "A long, narrow run. The Hunter wakes up fast.",
		HALF_X = 32,
		HALF_Z = 150,
		SPAWN_POSITION = Vector3.new(0, 0, 130),
		CORES = {{position = Vector3.new(0, 0, -130), hits = 5}},
		ESCAPE_POSITION = Vector3.new(0, 0, -130),
		BUDGET = 26,
		MAZE = {
			{-32, 12, 90, 92}, -- Alternating shelves: gap right, left, right...
			{-12, 32, 50, 52},
			{-32, 12, 10, 12},
			{-12, 32, -30, -28},
			{-32, 12, -70, -68},
			{-12, 32, -104, -102},
		},
		BUMPERS = {},
		HUNTER_LAIR_WAIT = 1,
		HUNTER_STALKS = false, -- Straight to the chase
	},
	{
		NAME = "Blackout",
		DESCRIPTION = "Dark rooms. Your flashlight battery runs out fast.",
		HALF_X = 72,
		HALF_Z = 110,
		SPAWN_POSITION = Vector3.new(0, 0, 88),
		CORES = {{position = Vector3.new(-40, 0, -88), hits = 5}},
		ESCAPE_POSITION = Vector3.new(-40, 0, -88),
		BUDGET = 28,
		MAZE = {
			{-72, -20, 50, 52}, -- Gap in the middle-left (-20..0)
			{0, 72, 50, 52},
			{-40, -38, 0, 50}, -- Room walls
			{20, 22, -10, 50},
			{-72, 40, -40, -38}, -- Gap on the right (40..72)
			{-10, -8, -110, -60}, -- Wall beside the core
			{44, 52, 20, 28},
			{-60, -52, -20, -12},
		},
		BUMPERS = {},
		HUNTER_LAIR_WAIT = 8,
		HUNTER_STALKS = true,
		HORROR_FOG = 0.85,
		-- The flashlight lasts DRAIN_SECONDS from full; each battery gives back REFILL (0..1)
		BATTERY = {
			DRAIN_SECONDS = 40,
			REFILL = 0.45,
			PICKUPS = {
				Vector3.new(10, 0, 30),
				Vector3.new(-55, 0, 20),
				Vector3.new(50, 0, 0),
				Vector3.new(60, 0, -60),
				Vector3.new(-25, 0, -50),
				Vector3.new(-60, 0, -75),
			},
		},
	},
	{
		NAME = "Two Hunters",
		DESCRIPTION = "One hunts you. One guards the way out.",
		HALF_X = 72,
		HALF_Z = 100,
		SPAWN_POSITION = Vector3.new(0, 0, 80),
		CORES = {{position = Vector3.new(0, 0, -80), hits = 6}},
		ESCAPE_POSITION = Vector3.new(0, 0, -80),
		BUDGET = 30,
		MAZE = {
			{-72, -12, 40, 42}, -- Gap in the middle (-12..12)
			{12, 72, 40, 42},
			{-50, -48, -30, 40}, -- Long side walls
			{48, 50, -30, 40},
			{-30, 30, -20, -18}, -- Middle bar
			{-72, -20, -50, -48}, -- Gap in the middle (-20..20) before the core
			{20, 72, -50, -48},
		},
		BUMPERS = {},
		HUNTER_LAIR_WAIT = 4,
		HUNTER_STALKS = true,
		HUNTERS = {"chaser", "guard"},
	},
}
