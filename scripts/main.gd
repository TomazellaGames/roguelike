extends Node2D

const MAP_WIDTH := 68
const MAP_HEIGHT := 36
const ROOM_COUNT := 15
const ROOM_MIN_SIZE := 4
const ROOM_MAX_SIZE := 9

const HEAL_ITEM_INTERVAL := 4
const WHEEL_OF_FORTUNE_INTERVAL := 7
const TOLL_INTERVAL := 10
const TOLL_WINDOW_LEVELS := 10
const TOLL_FRACTION := 0.15
const MAX_TRAPS_PER_LEVEL := 3
const HOLD_THRESHOLD_MSEC := 1500
const BLINK_DURATION_MSEC := 120

const DOOR_MIN_LEVEL := 11
const HIDDEN_TRAP_MIN_LEVEL := 11
const HIDDEN_TRAP_REVEAL_DISTANCE := 2

const GOAL_LEVEL := 21
const HP_SCORE_MAX := 1000
const GOLD_SCORE_PER_UNIT := 10
const TRAP_SCORE_PER_TRIGGER := 250
const BOOST_POTION_SCORE_PENALTY := -200
const GEAR_SCORE_PENALTY := -20

const WHEEL_OUTCOMES := [
	{"chance": 1, "id": "die"},
	{"chance": 1, "id": "lose_upgrade"},
	{"chance": 14, "id": "lose_half_hp"},
	{"chance": 14, "id": "lose_gear"},
	{"chance": 10, "id": "spawn_here"},
	{"chance": 10, "id": "spawn_elsewhere"},
	{"chance": 10, "id": "heal_full"},
	{"chance": 10, "id": "kill_random_monster"},
	{"chance": 14, "id": "heal_half_hp"},
	{"chance": 14, "id": "gear_upgrade"},
	{"chance": 1, "id": "gain_upgrade"},
	{"chance": 1, "id": "kill_room_monsters"},
]

@onready var ascii_renderer: AsciiRenderer = $AsciiRenderer
@onready var hud: Hud = $HUDLayer/HUD

var dungeon_map: DungeonMap
var rooms: Array = []
var player: Entity
var entities: Array = []
var item_pickups: Array = []
var stairs_pos: Vector2i
var turn_manager: TurnManager
var game_over := false
var game_won := false
var level := 1
var max_level_reached := 1
var _key_press_time: Dictionary = {}
var _blink_end_msec: int = -1

var doors_open := false
var switch_pos: Vector2i = Vector2i(-1, -1)
var hidden_trap_pos: Vector2i = Vector2i(-1, -1)

var stats_gold_collected := 0
var stats_gear_collected := 0
var stats_boost_potions_collected := 0

func _ready() -> void:
	hud.move_pressed.connect(_on_hud_move_pressed)
	hud.move_released.connect(_on_hud_move_released)
	hud.restart_pressed.connect(_on_hud_restart_pressed)
	hud.share_pressed.connect(_on_hud_share_pressed)
	hud.download_pressed.connect(_on_hud_download_pressed)
	new_game()

func _process(_delta: float) -> void:
	if game_over:
		return
	# While a direction key is held past HOLD_THRESHOLD_MSEC (charging a sprint move),
	# briefly hide the player glyph as a "charging" blink so the player gets visual
	# feedback before the double-step actually fires on key release.
	var now := Time.get_ticks_msec()
	for keycode in _key_press_time:
		var entry: Dictionary = _key_press_time[keycode]
		if not entry.blinked and now - entry.start >= HOLD_THRESHOLD_MSEC:
			entry.blinked = true
			player.blink_hidden = true
			_blink_end_msec = now + BLINK_DURATION_MSEC
			_render()
	if _blink_end_msec > 0 and now >= _blink_end_msec:
		player.blink_hidden = false
		_blink_end_msec = -1
		_render()

func new_game() -> void:
	randomize()
	game_over = false
	game_won = false
	level = 1
	if max_level_reached < 1:
		max_level_reached = 1
	stats_gold_collected = 0
	stats_gear_collected = 0
	stats_boost_potions_collected = 0
	hud.reset()
	player = Entity.new_player(Vector2i.ZERO)
	_start_level()

func _start_level() -> void:
	if level > max_level_reached:
		max_level_reached = level
	_generate_dungeon()
	player.grid_pos = rooms[0].get_center()
	entities = [player]
	_place_stairs()
	_place_doors_and_switch()
	_place_traps()
	_place_hidden_trap()
	_spawn_monsters()
	_spawn_items()
	_heal_on_level_start()
	_setup_turn_manager()
	hud.update_level(level, max_level_reached)
	hud.update_hp(player.hp, player.max_hp)
	hud.update_gold(player.gold)
	hud.update_gear(player.atk, player.defense, player.weapon, player.armor)
	_render()

func _heal_on_level_start() -> void:
	if player.hp <= floori(player.max_hp / 2.0):
		var heal_amount := floori(player.max_hp / 3.0)
		player.hp = min(player.max_hp, player.hp + heal_amount)
		hud.add_message("You catch your breath, recovering %d HP." % heal_amount)

func _generate_dungeon() -> void:
	dungeon_map = DungeonMap.new(MAP_WIDTH, MAP_HEIGHT)
	rooms = DungeonGenerator.generate(dungeon_map, ROOM_COUNT, ROOM_MIN_SIZE, ROOM_MAX_SIZE)

## Spawns one monster per room (except the start room), scaled up with hp_bonus/
## atk_bonus as the run gets deeper. Ghost is exempt from that scaling (it's
## always a fixed 1 HP/1 atk glass cannon) and spider/ogre/ghost are each
## capped at one live instance per floor via the spawned flags below.
func _spawn_monsters() -> void:
	var hp_bonus := level - 1
	var atk_bonus := floori((level - 1) / 3.0)
	var spider_spawned := false
	var ogre_spawned := false
	var ghost_spawned := false
	for i in range(1, rooms.size()):
		var def := _pick_monster_def(spider_spawned, ogre_spawned, ghost_spawned)
		var m := Entity.new_monster(rooms[i].get_center(), def)
		if def["name"] != "ghost":
			m.hp += hp_bonus
			m.max_hp += hp_bonus
			m.atk += atk_bonus
		match def["name"]:
			"spider":
				m.home_room = rooms[i]
				m.restrict_to_room = true
				spider_spawned = true
			"ogre":
				ogre_spawned = true
			"ghost":
				ghost_spawned = true
		entities.append(m)

## Picks a random monster def valid for the current level, excluding any of
## spider/ogre/ghost that already have a live instance this floor (each capped
## at one).
func _pick_monster_def(spider_spawned: bool, ogre_spawned: bool, ghost_spawned: bool = false) -> Dictionary:
	var candidates: Array = []
	for def in MonsterDefs.ALL:
		if level < def.get("min_level", 1):
			continue
		if def["name"] == "spider" and spider_spawned:
			continue
		if def["name"] == "ogre" and ogre_spawned:
			continue
		if def["name"] == "ghost" and ghost_spawned:
			continue
		candidates.append(def)
	return candidates[randi() % candidates.size()]

func _non_special_rooms() -> Array:
	var result: Array = []
	for room in rooms.slice(1):
		if room.get_center() != stairs_pos:
			result.append(room)
	return result

func _place_traps() -> void:
	var candidate_rooms := _non_special_rooms()
	candidate_rooms.shuffle()
	var trap_count: int = min(randi_range(0, MAX_TRAPS_PER_LEVEL), candidate_rooms.size())
	for i in range(trap_count):
		var pos := _random_trap_position(candidate_rooms[i])
		dungeon_map.set_tile(pos, Tile.Type.TRAP)

## Picks a random floor tile inside room, avoiding its center (reserved for a
## spawned monster). Reused for traps, the door switch, and the hidden trap.
## Falls back to the center if 20 random tries all land on it (tiny rooms).
func _random_trap_position(room: Rect2i) -> Vector2i:
	var inner := room.grow(-1)
	var center := room.get_center()
	for i in range(20):
		var pos := Vector2i(
			randi_range(inner.position.x, inner.position.x + inner.size.x - 1),
			randi_range(inner.position.y, inner.position.y + inner.size.y - 1)
		)
		if pos != center:
			return pos
	return center

func _spawn_items() -> void:
	# Each level guarantees 2 weapon drops and 2 armor drops (in rooms chosen at
	# random), plus a heal potion every HEAL_ITEM_INTERVAL levels. Drops are skipped
	# if there aren't enough non-special rooms to hold them.
	item_pickups = []
	var candidate_rooms := _non_special_rooms()
	candidate_rooms.shuffle()

	var level_bonus := floori((level - 1) / 2.0)

	var next_room := 0
	if candidate_rooms.size() > next_room:
		var weapon_def: Dictionary = ItemDefs.WEAPONS[randi() % ItemDefs.WEAPONS.size()].duplicate()
		weapon_def["atk_bonus"] += level_bonus
		item_pickups.append(_make_pickup(candidate_rooms[next_room], "weapon", weapon_def))
		next_room += 1
	if candidate_rooms.size() > next_room:
		var armor_def: Dictionary = ItemDefs.ARMOR[randi() % ItemDefs.ARMOR.size()].duplicate()
		armor_def["def_bonus"] += level_bonus
		item_pickups.append(_make_pickup(candidate_rooms[next_room], "armor", armor_def))
		next_room += 1
	if level % HEAL_ITEM_INTERVAL == 0 and candidate_rooms.size() > next_room:
		item_pickups.append(_make_pickup(candidate_rooms[next_room], "heal", ItemDefs.HEAL_POTION))
		next_room += 1
	if level % WHEEL_OF_FORTUNE_INTERVAL == 0 and candidate_rooms.size() > next_room:
		item_pickups.append(_make_pickup(candidate_rooms[next_room], "wheel", ItemDefs.WHEEL_OF_FORTUNE))
		next_room += 1
	if candidate_rooms.size() > next_room:
		var weapon_def: Dictionary = ItemDefs.WEAPONS[randi() % ItemDefs.WEAPONS.size()].duplicate()
		weapon_def["atk_bonus"] += level_bonus
		item_pickups.append(_make_pickup(candidate_rooms[next_room], "weapon", weapon_def))
		next_room += 1
	if candidate_rooms.size() > next_room:
		var armor_def: Dictionary = ItemDefs.ARMOR[randi() % ItemDefs.ARMOR.size()].duplicate()
		armor_def["def_bonus"] += level_bonus
		item_pickups.append(_make_pickup(candidate_rooms[next_room], "armor", armor_def))
		next_room += 1

func _make_pickup(room: Rect2i, slot: String, item_def: Dictionary) -> ItemPickup:
	var p := ItemPickup.new()
	p.grid_pos = room.get_center()
	p.slot = slot
	p.item_def = item_def
	return p

func _place_stairs() -> void:
	stairs_pos = rooms[rooms.size() - 1].get_center()
	dungeon_map.set_tile(stairs_pos, Tile.Type.STAIRS_DOWN)

## From DOOR_MIN_LEVEL on, seals every corridor connecting the stairs room with
## doors, and hides a switch in another (non-start, non-stairs) room that opens
## them. Falls back to leaving the doors open if no valid switch room exists,
## so the player is never locked out.
func _place_doors_and_switch() -> void:
	doors_open = false
	switch_pos = Vector2i(-1, -1)
	if level < DOOR_MIN_LEVEL:
		return
	var stairs_room: Rect2i = rooms[rooms.size() - 1]
	for pos in DungeonGenerator.find_room_exits(dungeon_map, stairs_room):
		dungeon_map.set_tile(pos, Tile.Type.DOOR)
	var candidate_rooms := _non_special_rooms()
	if candidate_rooms.is_empty():
		doors_open = true
		dungeon_map.open_doors()
		return
	candidate_rooms.shuffle()
	switch_pos = _random_trap_position(candidate_rooms[0])
	dungeon_map.set_tile(switch_pos, Tile.Type.SWITCH)
	# Safety net: doors are only meant to seal off the stairs room, but if a
	# corridor happens to graze it and gets sealed too, the switch room could
	# become unreachable. Rather than risk locking the player out, just leave
	# the doors open for the floor in that case.
	if not _is_reachable(rooms[0].get_center(), switch_pos):
		doors_open = true
		dungeon_map.open_doors()

## Flood-fills from `from` over walkable tiles (doors block, like walls) to check
## whether `to` can be reached without the switch having been triggered yet.
func _is_reachable(from: Vector2i, to: Vector2i) -> bool:
	var dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	var visited := {from: true}
	var queue: Array = [from]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if current == to:
			return true
		for dir in dirs:
			var next: Vector2i = current + dir
			if visited.has(next) or not dungeon_map.is_walkable(next):
				continue
			visited[next] = true
			queue.append(next)
	return false

## From HIDDEN_TRAP_MIN_LEVEL on, hides exactly one extra trap per floor that
## only becomes visible once the player gets close to it.
func _place_hidden_trap() -> void:
	hidden_trap_pos = Vector2i(-1, -1)
	if level < HIDDEN_TRAP_MIN_LEVEL:
		return
	var candidate_rooms := _non_special_rooms()
	if candidate_rooms.is_empty():
		return
	candidate_rooms.shuffle()
	hidden_trap_pos = _random_trap_position(candidate_rooms[0])
	dungeon_map.set_tile(hidden_trap_pos, Tile.Type.HIDDEN_TRAP)

## Opens the sealed stairs-room doors for the rest of the floor once the player
## steps on the hidden switch, and clears the switch glyph so it doesn't linger.
func _check_switch() -> void:
	if doors_open or switch_pos.x < 0:
		return
	if dungeon_map.get_tile(player.grid_pos) != Tile.Type.SWITCH:
		return
	doors_open = true
	dungeon_map.open_doors()
	dungeon_map.set_tile(switch_pos, Tile.Type.FLOOR)
	hud.add_message("You trigger the switch. Somewhere on this floor, doors grind open.")

## Reveals the hidden trap (turning it into a normal, visible TRAP tile) once the
## player comes within HIDDEN_TRAP_REVEAL_DISTANCE tiles of it (taxicab distance,
## which naturally covers "2 tiles orthogonally" and "1 tile diagonally").
func _check_hidden_trap_reveal() -> void:
	if hidden_trap_pos.x < 0:
		return
	if dungeon_map.get_tile(hidden_trap_pos) != Tile.Type.HIDDEN_TRAP:
		return
	var dist: int = absi(player.grid_pos.x - hidden_trap_pos.x) + absi(player.grid_pos.y - hidden_trap_pos.y)
	if dist <= HIDDEN_TRAP_REVEAL_DISTANCE:
		dungeon_map.set_tile(hidden_trap_pos, Tile.Type.TRAP)

func _setup_turn_manager() -> void:
	turn_manager = TurnManager.new()
	turn_manager.setup(dungeon_map, player, entities)
	turn_manager.message_logged.connect(_on_message_logged)
	turn_manager.player_died.connect(_on_player_died)

func _render() -> void:
	ascii_renderer.render(dungeon_map.tiles, turn_manager.entities, item_pickups)

func _on_message_logged(text: String) -> void:
	hud.add_message(text)

func _on_player_died() -> void:
	game_over = true
	hud.add_message("You have died.")
	hud.show_game_over(max_level_reached)

func _win_game() -> void:
	game_over = true
	game_won = true
	hud.add_message("You escaped the dungeon alive at floor %d!" % GOAL_LEVEL)
	hud.show_victory(_compute_score())

## Tallies the run into a score: remaining HP and collected gold count for you,
## triggered traps count for you (the risk paid off), and collected pickups
## count against you (a "flawless, unequipped" run scores highest) — potions
## the most, weapons/armor a little, wheel spins and doors not at all.
func _compute_score() -> Dictionary:
	var hp_score: int = int(round((1.0 - float(player.hp) / float(player.max_hp)) * HP_SCORE_MAX))
	var gold_score: int = stats_gold_collected * GOLD_SCORE_PER_UNIT
	var traps_score: int = player.traps_triggered * TRAP_SCORE_PER_TRIGGER
	var potion_score: int = stats_boost_potions_collected * BOOST_POTION_SCORE_PENALTY
	var gear_score: int = stats_gear_collected * GEAR_SCORE_PENALTY
	var total: int = hp_score + gold_score + traps_score + potion_score + gear_score
	return {
		"total": total,
		"lines": [
			["Remaining HP", hp_score],
			["Gold", gold_score],
			["Traps", traps_score],
			["Boost Potion", potion_score],
			["Gear", gear_score],
		],
	}

func _on_toll_failed(fee: int) -> void:
	game_over = true
	hud.add_message("You cannot pay the %d gold toll. Your journey ends here." % fee)
	hud.show_game_over(max_level_reached)

func _unhandled_input(event: InputEvent) -> void:
	if game_over:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ENTER:
			new_game()
		return

	if not (event is InputEventKey):
		return

	var dir := _keycode_to_direction(event.keycode)
	if dir == Vector2i.ZERO:
		return
	if event.pressed:
		if not event.echo:
			_key_press_time[event.keycode] = {"start": Time.get_ticks_msec(), "blinked": false}
		return

	var double_step := _consume_hold(event.keycode)
	_perform_move(dir, double_step)

func _on_hud_move_pressed(dir: Vector2i) -> void:
	if game_over:
		return
	_key_press_time[dir] = {"start": Time.get_ticks_msec(), "blinked": false}

func _on_hud_move_released(dir: Vector2i) -> void:
	if game_over:
		return
	var double_step := _consume_hold(dir)
	_perform_move(dir, double_step)

func _on_hud_restart_pressed() -> void:
	if game_over:
		new_game()

func _on_hud_share_pressed() -> void:
	if not game_over:
		return
	var image := ScreenshotService.capture(get_viewport())
	var path := ScreenshotService.share(image)
	if OS.has_feature("web"):
		hud.show_screenshot_status("Opening share sheet...")
	elif path != "":
		hud.show_screenshot_status("Opened screenshot for sharing.")
	else:
		hud.show_screenshot_status("Could not prepare screenshot for sharing.")

func _on_hud_download_pressed() -> void:
	if not game_over:
		return
	var image := ScreenshotService.capture(get_viewport())
	var path := ScreenshotService.download(image)
	if OS.has_feature("web"):
		hud.show_screenshot_status("Downloading screenshot...")
	elif path != "":
		hud.show_screenshot_status("Screenshot saved to %s" % path)
	else:
		hud.show_screenshot_status("Could not save screenshot.")

## Reports whether key/dir was held past HOLD_THRESHOLD_MSEC (a sprint), and
## clears the charging-blink state regardless, since the hold is now resolved.
func _consume_hold(key) -> bool:
	var held_msec := 0
	if _key_press_time.has(key):
		held_msec = Time.get_ticks_msec() - _key_press_time[key].start
		_key_press_time.erase(key)
	player.blink_hidden = false
	_blink_end_msec = -1
	return held_msec >= HOLD_THRESHOLD_MSEC

func _perform_move(dir: Vector2i, double_step: bool) -> void:
	var gold_before := player.gold
	turn_manager.process_player_turn(dir, double_step)
	# Any gold gained this turn came from killing monsters in combat (the only
	# other change, toll payment, happens separately in _check_stairs).
	var gold_gained := player.gold - gold_before
	if gold_gained > 0:
		stats_gold_collected += gold_gained
	if not game_over:
		_check_item_pickup()
	if not game_over:
		_check_switch()
		_check_hidden_trap_reveal()
		_check_stairs()
	hud.update_hp(player.hp, player.max_hp)
	hud.update_gold(player.gold)
	hud.update_gear(player.atk, player.defense, player.weapon, player.armor)
	_render()

## Resolves whatever pickup is sitting on the player's tile: equips gear,
## spins the Wheel of Fortune, or drinks a potion — then removes the pickup.
func _check_item_pickup() -> void:
	for pickup in item_pickups.duplicate():
		if pickup.grid_pos != player.grid_pos:
			continue
		if pickup.slot == "weapon":
			player.equip_weapon(pickup.item_def)
			stats_gear_collected += 1
			hud.add_message("You wield a %s." % pickup.item_def["name"])
		elif pickup.slot == "armor":
			player.equip_armor(pickup.item_def)
			stats_gear_collected += 1
			hud.add_message("You wear %s." % pickup.item_def["name"])
		elif pickup.slot == "wheel":
			_spin_wheel_of_fortune()
		else:
			_get_heal_item()
			var msg := "You drink the %s. Max HP is now %d. Offense is now %d. Defense is now %d." % [pickup.item_def["name"], player.max_hp, player.atk, player.defense]
			hud.add_message(msg)
		item_pickups.erase(pickup)
		
## Applies a permanent stat boost (used both for heal potion pickups and the
## debug "add upgrade" cheat). Returns true every 3rd upgrade, which callers
## can use to signal a bigger milestone.
func _get_heal_item() -> bool:
	player.heal_items_consumed += 1
	stats_boost_potions_collected += 1
	player.max_hp += 3
	player.base_atk += 1
	player.base_defense += 1
	player.crit_chance += 0.01
	player.recompute_stats()
	player.hp = player.max_hp
	return player.heal_items_consumed % 3 == 0

## Rolls a weighted outcome from WHEEL_OUTCOMES, applies its effect, and logs
## only the outcome that hit along with its odds.
func _spin_wheel_of_fortune() -> void:
	var roll := randi_range(1, 100)
	var cumulative := 0
	var outcome: Dictionary = WHEEL_OUTCOMES[WHEEL_OUTCOMES.size() - 1]
	for entry in WHEEL_OUTCOMES:
		cumulative += entry["chance"]
		if roll <= cumulative:
			outcome = entry
			break
	var effect_msg := _apply_wheel_outcome(outcome["id"])
	hud.add_message("The Wheel of Fortune spins... %s (%d%% chance)" % [effect_msg, outcome["chance"]])
	if player.hp <= 0 and not game_over:
		_on_player_died()

## Applies the effect for a rolled WHEEL_OUTCOMES id and returns its log line;
## see _spin_wheel_of_fortune for how id is chosen.
func _apply_wheel_outcome(id: String) -> String:
	match id:
		"die":
			player.hp = 0
			return "You are struck down instantly!"
		"lose_upgrade":
			return _wheel_lose_upgrade()
		"lose_half_hp":
			var dmg := floori(player.max_hp / 2.0)
			player.hp = max(0, player.hp - dmg)
			return "You lose %d HP!" % dmg
		"lose_gear":
			player.unequip_weapon()
			player.unequip_armor()
			return "Your weapon and armor crumble to dust!"
		"spawn_here":
			return _wheel_spawn_monster(_room_containing(player.grid_pos))
		"spawn_elsewhere":
			return _wheel_spawn_monster(_random_room_other_than(player.grid_pos))
		"heal_full":
			player.hp = player.max_hp
			return "You are fully healed!"
		"kill_random_monster":
			return _wheel_kill_random_monster()
		"heal_half_hp":
			var heal := floori(player.max_hp / 2.0)
			player.hp = min(player.max_hp, player.hp + heal)
			return "You recover %d HP!" % heal
		"gear_upgrade":
			return _wheel_gear_upgrade()
		"gain_upgrade":
			_get_heal_item()
			return "You feel permanently stronger!"
		"kill_room_monsters":
			return _wheel_kill_room_monsters()
	return ""

## Exactly reverses one _get_heal_item() boost (the wheel's "bad" mirror of a
## heal potion); does nothing if the player hasn't collected any yet.
func _wheel_lose_upgrade() -> String:
	if player.heal_items_consumed <= 0:
		return "...but you have no upgrades to lose."
	player.heal_items_consumed -= 1
	player.max_hp -= 3
	player.base_atk -= 1
	player.base_defense -= 1
	player.crit_chance = max(0.0, player.crit_chance - 0.01)
	player.recompute_stats()
	player.hp = min(player.hp, player.max_hp)
	return "You feel weaker. One of your upgrades fades away."

func _wheel_gear_upgrade() -> String:
	var level_bonus := floori((level - 1) / 2.0)
	var spear: Dictionary = ItemDefs.WEAPONS[2].duplicate()
	spear["atk_bonus"] += level_bonus
	player.equip_weapon(spear)
	var chainmail: Dictionary = ItemDefs.ARMOR[1].duplicate()
	chainmail["def_bonus"] += level_bonus
	player.equip_armor(chainmail)
	stats_gear_collected += 2
	return "You are gifted a Spear and Chainmail!"

func _room_containing(pos: Vector2i) -> Rect2i:
	for room in rooms:
		if room.has_point(pos):
			return room
	return rooms[0]

func _random_room_other_than(pos: Vector2i) -> Rect2i:
	var current := _room_containing(pos)
	var others: Array = rooms.filter(func(r): return r != current)
	if others.is_empty():
		return current
	return others[randi() % others.size()]

func _has_monster_named(monster_name: String) -> bool:
	for e in turn_manager.entities:
		if e != player and e.hp > 0 and e.display_name == monster_name:
			return true
	return false

## Spawns one extra monster mid-floor, mirroring _spawn_monsters' level-scaling
## and one-per-floor rules for spider/ogre/ghost (checked against live entities
## instead of this level's spawn flags, since it happens after the initial spawn).
func _wheel_spawn_monster(room: Rect2i) -> String:
	var def := _pick_monster_def(_has_monster_named("spider"), _has_monster_named("ogre"), _has_monster_named("ghost"))
	var m := Entity.new_monster(room.get_center(), def)
	if def["name"] != "ghost":
		m.hp += level - 1
		m.max_hp += level - 1
		m.atk += floori((level - 1) / 3.0)
	if def["name"] == "spider":
		m.home_room = room
		m.restrict_to_room = true
	turn_manager.entities.append(m)
	return "A %s appears!" % def["name"]

func _wheel_kill_random_monster() -> String:
	var candidates: Array = []
	for e in turn_manager.entities:
		if e != player and e.hp > 0:
			candidates.append(e)
	if candidates.is_empty():
		return "...but there are no monsters left to slay."
	var target: Entity = candidates[randi() % candidates.size()]
	var gold := randi_range(target.gold_min, target.gold_max)
	target.hp = 0
	player.gold += gold
	stats_gold_collected += gold
	return "A %s dies in a burst of light! You gain %d gold." % [target.display_name, gold]

func _wheel_kill_room_monsters() -> String:
	var room := _room_containing(player.grid_pos)
	var total_gold := 0
	var count := 0
	for e in turn_manager.entities:
		if e != player and e.hp > 0 and room.has_point(e.grid_pos):
			total_gold += randi_range(e.gold_min, e.gold_max)
			e.hp = 0
			count += 1
	if count == 0:
		return "...but there are no monsters in this room."
	player.gold += total_gold
	stats_gold_collected += total_gold
	return "Every monster in the room is annihilated! You gain %d gold." % total_gold

func _check_stairs() -> void:
	if dungeon_map.get_tile(player.grid_pos) != Tile.Type.STAIRS_DOWN:
		return
	var next_level := level + 1
	if next_level == GOAL_LEVEL:
		# Reaching the goal floor ends the run in victory instead of generating it.
		level = next_level
		if level > max_level_reached:
			max_level_reached = level
		_win_game()
		return
	# Every TOLL_INTERVAL levels, the player must pay a gold toll to descend
	# further; failing to pay ends the run.
	if next_level % TOLL_INTERVAL == 0:
		var fee := _toll_fee()
		if player.gold < fee:
			_on_toll_failed(fee)
			return
		player.gold -= fee
		player.hp = player.max_hp
		hud.add_message("You pay the toll of %d gold to proceed. The journey's toll fully restores you." % fee)
	level = next_level
	hud.add_message("You descend to floor %d." % level)
	_start_level()

## Toll is priced as a fraction of the gold a player could plausibly have earned
## over the last TOLL_WINDOW_LEVELS, based on average monster gold drops per level.
func _toll_fee() -> int:
	var avg_monsters_per_level := float(ROOM_COUNT - 1)
	var avg_gold_per_level := avg_monsters_per_level * MonsterDefs.average_gold()
	var avg_gold_over_window := avg_gold_per_level * TOLL_WINDOW_LEVELS
	return int(round(avg_gold_over_window * TOLL_FRACTION))

func _keycode_to_direction(keycode: int) -> Vector2i:
	match keycode:
		KEY_UP, KEY_KP_8, KEY_K, KEY_W:
			return Vector2i(0, -1)
		KEY_DOWN, KEY_KP_2, KEY_J, KEY_S:
			return Vector2i(0, 1)
		KEY_LEFT, KEY_KP_4, KEY_H, KEY_A:
			return Vector2i(-1, 0)
		KEY_RIGHT, KEY_KP_6, KEY_L, KEY_D:
			return Vector2i(1, 0)
	return Vector2i.ZERO
