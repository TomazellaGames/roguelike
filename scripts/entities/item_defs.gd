class_name ItemDefs
extends RefCounted

const WEAPONS := [
	{"name": "Dagger", "glyph": "/", "color": Color(0.8, 0.8, 0.8), "atk_bonus": 1, "durability_max": 9, "crit_mult": 2.0},
	{"name": "Short Sword", "glyph": "/", "color": Color(0.8, 0.8, 1.0), "atk_bonus": 3, "durability_max": 7},
	{"name": "Spear", "glyph": "/", "color": Color(0.8, 0.9, 0.5), "atk_bonus": 4, "durability_max": 6, "reach": true},
	{"name": "Long Sword", "glyph": "/", "color": Color(0.6, 0.8, 1.0), "atk_bonus": 5, "durability_max": 5},
	{"name": "War Axe", "glyph": "/", "color": Color(1.0, 0.6, 0.2), "atk_bonus": 7, "durability_max": 4},
]

const ARMOR := [
	{"name": "Leather Armor", "glyph": "[", "color": Color(0.7, 0.5, 0.3), "def_bonus": 1, "durability_max": 9},
	{"name": "Chainmail", "glyph": "[", "color": Color(0.75, 0.75, 0.85), "def_bonus": 3, "durability_max": 7},
	{"name": "Plate Armor", "glyph": "[", "color": Color(0.85, 0.85, 1.0), "def_bonus": 5, "durability_max": 5},
]

const HEAL_POTION := {
	"name": "Potion of Vitality",
	"glyph": "+",
	"color": Color(1.0, 0.3, 0.6),
}

const WHEEL_OF_FORTUNE := {
	"name": "Wheel of Fortune",
	"glyph": "%",
	"color": Color(1.0, 1.0, 0.0),
}
