class_name AsciiRenderer
extends Node2D

@export var cell_size := Vector2(14, 20)
@export var font_size := 16

var font: Font
var _map_tiles: Array = []
var _entities: Array = []
var _item_pickups: Array = []

func _ready() -> void:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Cascadia Mono", "Consolas", "Courier New", "monospace"])
	font = f

func render(map_tiles: Array, entities: Array = [], item_pickups: Array = []) -> void:
	_map_tiles = map_tiles
	_entities = entities
	_item_pickups = item_pickups
	queue_redraw()

func _draw() -> void:
	if font == null:
		return
	for y in _map_tiles.size():
		var row: Array = _map_tiles[y]
		for x in row.size():
			var info: Dictionary = Tile.GLYPHS[row[x]]
			draw_string(font, Vector2(x * cell_size.x, y * cell_size.y + font_size), info.glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, info.color)
	for item in _item_pickups:
		draw_string(font, Vector2(item.grid_pos.x * cell_size.x, item.grid_pos.y * cell_size.y + font_size), item.item_def.glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, item.item_def.color)
	for e in _entities:
		if e.hp <= 0 or e.blink_hidden:
			continue
		draw_string(font, Vector2(e.grid_pos.x * cell_size.x, e.grid_pos.y * cell_size.y + font_size), e.glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, e.color)
