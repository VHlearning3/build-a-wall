-- Badge ids from the Creator Dashboard. 0 means "not created yet" and is skipped.
-- To add one: Creator Dashboard > your experience > Engagement > Badges > Create a Badge,
-- then copy its id (the number in the badge's URL) here.
return {
	-- One badge per level, awarded when the player escapes that level (index = level number)
	Levels = {
		0, -- 1 The Grid
		0, -- 2 Bumper Hall
		0, -- 3 Twin Cores
		0, -- 4 The Long Corridor
		0, -- 5 Blackout
		0, -- 6 Two Hunters
	},
	Flawless = 0, -- "No Deaths": escaped any level without dying
}
