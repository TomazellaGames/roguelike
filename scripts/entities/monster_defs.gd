class_name MonsterDefs
extends RefCounted

const RAT := {
	"name": "rat",
	"glyph": "r",
	"color": Color(0.6, 0.4, 0.2),
	"hp": 4,
	"atk": 1,
	"sight_radius": 5,
	"gold_min": 2,
	"gold_max": 3,
}

const GOBLIN := {
	"name": "goblin",
	"glyph": "g",
	"color": Color(0.2, 0.7, 0.2),
	"hp": 8,
	"atk": 2,
	"sight_radius": 6,
	"gold_min": 5,
	"gold_max": 6,
}

const SPIDER := {
	"name": "spider",
	"glyph": "s",
	"color": Color(0.5, 0.1, 0.5),
	"hp": 12,
	"atk": 3,
	"sight_radius": 4,
	"gold_min": 8,
	"gold_max": 11,
	"min_level": 6,
	"trap_immune": true,
}

const OGRE := {
	"name": "ogre",
	"glyph": "O",
	"color": Color(0.4, 0.6, 0.8),
	"hp": 30,
	"atk": 7,
	"defense": 3,
	"sight_radius": 6,
	"gold_min": 9,
	"gold_max": 12,
	"min_level": 9,
	"half_speed": true,
}

const GHOST := {
	"name": "ghost",
	"glyph": "G",
	"color": Color(0.85, 0.85, 1.0, 0.55),
	"hp": 1,
	"atk": 1,
	"defense": 0,
	"sight_radius": 4,
	"gold_min": 0,
	"gold_max": 0,
	"min_level": 14,
	"trap_immune": true,
	"phases_walls": true,
	"move_steps": 2,
	"dodge_chance": 0.5,
}

const ALL := [RAT, GOBLIN, SPIDER, OGRE, GHOST]

static func average_gold() -> float:
	var total := 0.0
	for def in ALL:
		total += (def["gold_min"] + def["gold_max"]) / 2.0
	return total / ALL.size()
