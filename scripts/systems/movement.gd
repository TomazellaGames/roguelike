class_name Movement
extends RefCounted

## Attempts to step one tile in dir. If the tile is occupied, attacks instead of
## moving. Otherwise moves, then resolves trap damage and, for reach weapons
## (e.g. Spear), a free follow-up attack on any now-adjacent hostile.
static func try_move(entity: Entity, dir: Vector2i, map: DungeonMap, entities: Array) -> String:
	var target := entity.grid_pos + dir
	if not map.is_walkable(target):
		return ""
	for other in entities:
		if other == entity or other.hp <= 0:
			continue
		if other.grid_pos == target:
			return Combat.resolve_attack(entity, other)
	entity.grid_pos = target

	var msg := ""
	if map.get_tile(target) == Tile.Type.TRAP and not entity.trap_immune:
		msg = _trigger_trap(entity)

	if entity.hp > 0 and entity.weapon != null and entity.weapon.get("reach", false):
		var reach_target := _find_adjacent_hostile(entity, entities)
		if reach_target != null:
			var reach_msg := Combat.resolve_attack(entity, reach_target)
			msg = (msg + " " + reach_msg) if msg != "" else reach_msg

	return msg

static func _trigger_trap(entity: Entity) -> String:
	var dmg: int = max(1, floori(entity.max_hp / 2))
	entity.hp -= dmg
	var name := "You" if entity.is_player else entity.display_name.capitalize()
	var verb := "step" if entity.is_player else "steps"
	var msg := "%s %s on a spike trap for %d damage!" % [name, verb, dmg]
	if entity.hp <= 0:
		var die_verb := "die" if entity.is_player else "dies"
		msg += " %s %s!" % [name, die_verb]
	return msg

static func _find_adjacent_hostile(entity: Entity, entities: Array) -> Entity:
	for other in entities:
		if other == entity or other.hp <= 0 or other.is_player == entity.is_player:
			continue
		var diff: Vector2i = other.grid_pos - entity.grid_pos
		if (diff.x == 0 and abs(diff.y) == 1) or (diff.y == 0 and abs(diff.x) == 1):
			return other
	return null
