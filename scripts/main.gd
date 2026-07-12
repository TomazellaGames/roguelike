extends Node2D

const MAP_WIDTH := 68
const MAP_HEIGHT := 36
const ROOM_COUNT := 15
const ROOM_MIN_SIZE := 4
const ROOM_MAX_SIZE := 9

const HEAL_ITEM_INTERVAL := 4
const TOLL_INTERVAL := 10
const TOLL_WINDOW_LEVELS := 10
const TOLL_FRACTION := 0.15
const MAX_TRAPS_PER_LEVEL := 3
const HOLD_THRESHOLD_MSEC := 1500
const BLINK_DURATION_MSEC := 120

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
var level := 1
var max_level_reached := 1
var _key_press_time: Dictionary = {}
var _blink_end_msec: int = -1

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
	level = 1
	if max_level_reached < 1:
		max_level_reached = 1
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
	_place_traps()
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

func _spawn_monsters() -> void:
	var hp_bonus := level - 1
	var atk_bonus := floori((level - 1) / 3.0)
	var spider_spawned := false
	var ogre_spawned := false
	for i in range(1, rooms.size()):
		var def := _pick_monster_def(spider_spawned, ogre_spawned)
		var m := Entity.new_monster(rooms[i].get_center(), def)
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
		entities.append(m)

func _pick_monster_def(spider_spawned: bool, ogre_spawned: bool) -> Dictionary:
	var candidates: Array = []
	for def in MonsterDefs.ALL:
		if level < def.get("min_level", 1):
			continue
		if def["name"] == "spider" and spider_spawned:
			continue
		if def["name"] == "ogre" and ogre_spawned:
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
	
	# TODO remove this on builds
	# Debug cheat codes: Shift/Ctrl/Alt + a key grants gear, gold, or heals for testing.
	_debug_codes(event)
		
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

func _consume_hold(key) -> bool:
	var held_msec := 0
	if _key_press_time.has(key):
		held_msec = Time.get_ticks_msec() - _key_press_time[key].start
		_key_press_time.erase(key)
	player.blink_hidden = false
	_blink_end_msec = -1
	return held_msec >= HOLD_THRESHOLD_MSEC

func _perform_move(dir: Vector2i, double_step: bool) -> void:
	turn_manager.process_player_turn(dir, double_step)
	if not game_over:
		_check_item_pickup()
		_check_stairs()
	hud.update_hp(player.hp, player.max_hp)
	hud.update_gold(player.gold)
	hud.update_gear(player.atk, player.defense, player.weapon, player.armor)
	_render()

func _check_item_pickup() -> void:
	for pickup in item_pickups.duplicate():
		if pickup.grid_pos != player.grid_pos:
			continue
		if pickup.slot == "weapon":
			player.equip_weapon(pickup.item_def)
			hud.add_message("You wield a %s." % pickup.item_def["name"])
		elif pickup.slot == "armor":
			player.equip_armor(pickup.item_def)
			hud.add_message("You wear %s." % pickup.item_def["name"])
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
	player.max_hp += 3
	player.base_atk += 1
	player.base_defense += 1
	player.crit_chance += 0.01
	player.recompute_stats()
	player.hp = player.max_hp
	return player.heal_items_consumed % 3 == 0

func _check_stairs() -> void:
	if dungeon_map.get_tile(player.grid_pos) != Tile.Type.STAIRS_DOWN:
		return
	# Every TOLL_INTERVAL levels, the player must pay a gold toll to descend
	# further; failing to pay ends the run.
	var next_level := level + 1
	if next_level % TOLL_INTERVAL == 0:
		var fee := _toll_fee()
		if player.gold < fee:
			_on_toll_failed(fee)
			return
		player.gold -= fee
		hud.add_message("You pay the toll of %d gold to proceed." % fee)
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

func _debug_codes(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var weapon_added
		var armor_added
		var has_changes: bool = false
		if Input.is_key_pressed(KEY_SHIFT):
			if event.keycode == KEY_APOSTROPHE:
				player.unequip_weapon()
				printerr("DEBUG: unequip weapon")
				has_changes = true
			elif event.keycode == KEY_1:
				weapon_added = ItemDefs.WEAPONS[0].duplicate()
				has_changes = true
			elif event.keycode == KEY_2:
				weapon_added = ItemDefs.WEAPONS[1].duplicate()
				has_changes = true
			elif event.keycode == KEY_3:
				weapon_added = ItemDefs.WEAPONS[2].duplicate()
				has_changes = true
			elif event.keycode == KEY_4:
				weapon_added = ItemDefs.WEAPONS[3].duplicate()
				has_changes = true
			elif event.keycode == KEY_5:
				weapon_added = ItemDefs.WEAPONS[4].duplicate()
				has_changes = true
		elif Input.is_key_pressed(KEY_CTRL):
			if event.keycode == KEY_APOSTROPHE:
				player.unequip_armor()
				printerr("DEBUG: unequip armor")
				has_changes = true
			elif event.keycode == KEY_1:
				armor_added = ItemDefs.ARMOR[0].duplicate()
				has_changes = true
			elif event.keycode == KEY_2:
				armor_added = ItemDefs.ARMOR[1].duplicate()
				has_changes = true
			elif event.keycode == KEY_3:
				armor_added = ItemDefs.ARMOR[2].duplicate()
				has_changes = true
		elif Input.is_key_pressed(KEY_ALT):
			if event.keycode == KEY_2:
				_get_heal_item()
				printerr("DEBUG: adding one Upgrade")
				has_changes = true
			elif event.keycode == KEY_1:
				player.gold += 5
				printerr("DEBUG: adding 5 gold")
				has_changes = true
			elif event.keycode == KEY_APOSTROPHE:
				player.hp = player.max_hp
				printerr("DEBUG: Full Heal")
				has_changes = true
		if has_changes:
			var level_bonus := floori((level - 1) / 2.0)
			if weapon_added:
				weapon_added["atk_bonus"] += level_bonus
				player.equip_weapon(weapon_added)
				printerr("DEBUG: equip weapon " + weapon_added.name)
			if armor_added:
				armor_added["def_bonus"] += level_bonus
				player.equip_armor(armor_added)
				printerr("DEBUG: equip armor " + armor_added.name)
			hud.update_gear(player.atk, player.defense, player.weapon, player.armor)
			hud.update_hp(player.hp, player.max_hp)
			hud.update_gold(player.gold)
			hud.add_message("DEBUG: You used a cheat code!")
			_render()
			
