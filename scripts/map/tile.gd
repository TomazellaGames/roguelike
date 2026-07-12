class_name Tile
extends RefCounted

enum Type { WALL, FLOOR, STAIRS_DOWN, TRAP }

const GLYPHS := {
	Type.WALL: {"glyph": "#", "color": Color(0.55, 0.55, 0.6)},
	Type.FLOOR: {"glyph": ".", "color": Color(0.35, 0.35, 0.42)},
	Type.STAIRS_DOWN: {"glyph": ">", "color": Color(1.0, 0.9, 0.2)},
	Type.TRAP: {"glyph": "^", "color": Color(1.0, 0.3, 0.2)},
}
