class_name DungeonGenerator
extends RefCounted

## Randomly places non-overlapping rooms (with a 1-tile buffer between them) and
## connects each new room to the previous one with an L-shaped corridor. Gives up
## early if it can't fit room_count rooms within max_attempts random placements.
static func generate(map: DungeonMap, room_count: int, min_size: int, max_size: int) -> Array:
	var rooms: Array = []
	var attempts := 0
	var max_attempts := room_count * 30
	while rooms.size() < room_count and attempts < max_attempts:
		attempts += 1
		var w := randi_range(min_size, max_size)
		var h := randi_range(min_size, max_size)
		var x := randi_range(1, map.width - w - 2)
		var y := randi_range(1, map.height - h - 2)
		var room := Rect2i(x, y, w, h)
		var overlaps := false
		for other in rooms:
			if room.grow(1).intersects(other):
				overlaps = true
				break
		if overlaps:
			continue
		_carve_room(map, room)
		if rooms.size() > 0:
			_carve_corridor(map, rooms[rooms.size() - 1].get_center(), room.get_center())
		rooms.append(room)
	return rooms

## Finds every FLOOR tile just outside room that's orthogonally adjacent to it —
## i.e. the corridor tiles where the room connects to the rest of the dungeon.
static func find_room_exits(map: DungeonMap, room: Rect2i) -> Array:
	var exits := {}
	var dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	for x in range(room.position.x, room.position.x + room.size.x):
		for y in range(room.position.y, room.position.y + room.size.y):
			var pos := Vector2i(x, y)
			for dir in dirs:
				var neighbor: Vector2i = pos + dir
				if room.has_point(neighbor):
					continue
				if map.get_tile(neighbor) == Tile.Type.FLOOR:
					exits[neighbor] = true
	return exits.keys()

static func _carve_room(map: DungeonMap, room: Rect2i) -> void:
	for y in range(room.position.y, room.position.y + room.size.y):
		for x in range(room.position.x, room.position.x + room.size.x):
			map.set_tile(Vector2i(x, y), Tile.Type.FLOOR)

## Carves an L-shaped corridor between two points, moving along one axis fully
## before the other. Which axis goes first is randomized so corridors don't all
## bend the same way.
static func _carve_corridor(map: DungeonMap, from: Vector2i, to: Vector2i) -> void:
	var current := from
	var horizontal_first := randi() % 2 == 0
	if horizontal_first:
		while current.x != to.x:
			map.set_tile(current, Tile.Type.FLOOR)
			current.x += 1 if to.x > current.x else -1
		while current.y != to.y:
			map.set_tile(current, Tile.Type.FLOOR)
			current.y += 1 if to.y > current.y else -1
	else:
		while current.y != to.y:
			map.set_tile(current, Tile.Type.FLOOR)
			current.y += 1 if to.y > current.y else -1
		while current.x != to.x:
			map.set_tile(current, Tile.Type.FLOOR)
			current.x += 1 if to.x > current.x else -1
	map.set_tile(to, Tile.Type.FLOOR)
