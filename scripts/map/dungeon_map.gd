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
	if pos.x < 0 or pos.x >= width or pos.y < 0 or pos.y >= height:
		return Tile.Type.WALL
	return tiles[pos.y][pos.x]

func set_tile(pos: Vector2i, type: int) -> void:
	if pos.x < 0 or pos.x >= width or pos.y < 0 or pos.y >= height:
		return
	tiles[pos.y][pos.x] = type

func is_walkable(pos: Vector2i) -> bool:
	var t := get_tile(pos)
	return t == Tile.Type.FLOOR or t == Tile.Type.STAIRS_DOWN or t == Tile.Type.TRAP
