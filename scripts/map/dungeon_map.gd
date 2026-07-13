class_name DungeonMap
extends RefCounted

var width: int
var height: int
var tiles: Array = []

func _init(w: int, h: int) -> void:
	width = w
	height = h
	fill(Tile.Type.WALL)

func fill(type: int) -> void:
	tiles = []
	for y in height:
		var row: Array = []
		for x in width:
			row.append(type)
		tiles.append(row)

func get_tile(pos: Vector2i) -> int:
	if not is_in_bounds(pos):
		return Tile.Type.WALL
	return tiles[pos.y][pos.x]

func set_tile(pos: Vector2i, type: int) -> void:
	if not is_in_bounds(pos):
		return
	tiles[pos.y][pos.x] = type

func is_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < width and pos.y >= 0 and pos.y < height

func is_walkable(pos: Vector2i) -> bool:
	var t := get_tile(pos)
	return t == Tile.Type.FLOOR or t == Tile.Type.STAIRS_DOWN or t == Tile.Type.TRAP \
		or t == Tile.Type.SWITCH or t == Tile.Type.HIDDEN_TRAP

## Converts every DOOR tile back to FLOOR (used when a level switch is triggered).
func open_doors() -> void:
	for y in height:
		for x in width:
			if tiles[y][x] == Tile.Type.DOOR:
				tiles[y][x] = Tile.Type.FLOOR
