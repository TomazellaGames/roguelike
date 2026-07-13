class_name MonsterAI
extends RefCounted

static func take_turn(monster: Entity, player: Entity, map: DungeonMap, entities: Array) -> String:
	var dist := _chebyshev_distance(monster.grid_pos, player.grid_pos)
	if dist > monster.sight_radius:
		return ""

	if monster.half_speed:
		return _take_half_speed_turn(monster, player, map, entities)

	if monster.move_steps > 1:
		return _take_multi_step_turn(monster, player, map, entities)

	if _is_orthogonal_adjacent(monster.grid_pos, player.grid_pos):
		return Combat.resolve_attack(monster, player)

	var delta := player.grid_pos - monster.grid_pos
	var dir := _choose_direction(monster, delta, map)
	if dir == Vector2i.ZERO:
		return ""
	return Movement.try_move(monster, dir, map, entities)

## Half-speed monsters (e.g. Ogre) alternate between an idle "resting" turn and a
## normal turn, so they effectively act once every two turns.
static func _take_half_speed_turn(monster: Entity, player: Entity, map: DungeonMap, entities: Array) -> String:
	if monster.resting:
		monster.resting = false
		return ""
	monster.resting = true

	if _is_orthogonal_adjacent(monster.grid_pos, player.grid_pos):
		return Combat.resolve_attack(monster, player)

	var delta := player.grid_pos - monster.grid_pos
	var dir := _choose_direction(monster, delta, map)
	if dir == Vector2i.ZERO:
		return ""
	return Movement.try_move(monster, dir, map, entities)

## Monsters with move_steps > 1 (e.g. Ghost) advance up to that many tiles toward
## the player in a single turn instead of attacking-or-moving-once. They still
## use their whole turn to attack if already adjacent, and stop advancing early
## if a step becomes eventful (attack/trap) or brings them adjacent to the player.
static func _take_multi_step_turn(monster: Entity, player: Entity, map: DungeonMap, entities: Array) -> String:
	if _is_orthogonal_adjacent(monster.grid_pos, player.grid_pos):
		return Combat.resolve_attack(monster, player)

	var msgs: Array = []
	for i in range(monster.move_steps):
		var delta := player.grid_pos - monster.grid_pos
		var dir := _choose_direction(monster, delta, map, monster.phases_walls)
		if dir == Vector2i.ZERO:
			break
		var step_msg := Movement.try_move(monster, dir, map, entities)
		if step_msg != "":
			msgs.append(step_msg)
			break
		if _is_orthogonal_adjacent(monster.grid_pos, player.grid_pos):
			break
	return " ".join(msgs)

## Greedily steps toward the player: tries the axis with the larger distance
## first (primary), falling back to the other axis (secondary) if blocked, so
## monsters can route around corners instead of getting stuck on walls.
## ignore_walls lets wall-phasing monsters treat any in-bounds tile as steppable.
static func _choose_direction(monster: Entity, delta: Vector2i, map: DungeonMap, ignore_walls: bool = false) -> Vector2i:
	var from := monster.grid_pos
	var x_dir := Vector2i(sign(delta.x), 0) if delta.x != 0 else Vector2i.ZERO
	var y_dir := Vector2i(0, sign(delta.y)) if delta.y != 0 else Vector2i.ZERO
	var primary := x_dir if abs(delta.x) >= abs(delta.y) else y_dir
	var secondary := y_dir if primary == x_dir else x_dir

	if primary != Vector2i.ZERO and _can_step(monster, from + primary, map, ignore_walls):
		return primary
	if secondary != Vector2i.ZERO and _can_step(monster, from + secondary, map, ignore_walls):
		return secondary
	return Vector2i.ZERO

static func _can_step(monster: Entity, target: Vector2i, map: DungeonMap, ignore_walls: bool = false) -> bool:
	if ignore_walls:
		if not map.is_in_bounds(target):
			return false
	elif not map.is_walkable(target):
		return false
	if monster.restrict_to_room and not monster.home_room.has_point(target):
		return false
	return true

static func _chebyshev_distance(a: Vector2i, b: Vector2i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y))

static func _is_orthogonal_adjacent(a: Vector2i, b: Vector2i) -> bool:
	var diff := a - b
	return (diff.x == 0 and abs(diff.y) == 1) or (diff.y == 0 and abs(diff.x) == 1)
