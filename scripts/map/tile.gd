class_name Tile
extends RefCounted

enum Type { WALL, FLOOR, STAIRS_DOWN, TRAP, DOOR, SWITCH, HIDDEN_TRAP }

const GLYPHS := {
	Type.WALL: {"glyph": "#", "color": Color(0.55, 0.55, 0.6)},
	Type.FLOOR: {"glyph": ".", "color": Color(0.35, 0.35, 0.42)},
	Type.STAIRS_DOWN: {"glyph": ">", "color": Color(1.0, 0.9, 0.2)},
	Type.TRAP: {"glyph": "^", "color": Color(1.0, 0.3, 0.2)},
	Type.DOOR: {"glyph": "#", "color": Color(0.6, 0.35, 0.1)},
	Type.SWITCH: {"glyph": "\\", "color": Color(0.2, 0.9, 0.7)},
	# Renders identical to FLOOR until DungeonMap converts it to TRAP (on reveal or trigger).
	Type.HIDDEN_TRAP: {"glyph": ".", "color": Color(0.35, 0.35, 0.42)},
}
