class_name TurnManager
extends RefCounted

signal message_logged(text: String)
signal player_died

var accepting_input := true

var map: DungeonMap
var player: Entity
var entities: Array

func setup(p_map: DungeonMap, p_player: Entity, p_entities: Array) -> void:
	map = p_map
	player = p_player
	entities = p_entities
	accepting_input = true

## Advances one full turn: moves/attacks with the player (twice if sprinting),
## then lets every other entity act in turn order. double_step (sprint) only
## applies if the first step actually succeeded and costs the player 1 HP.
func process_player_turn(dir: Vector2i, double_step: bool = false) -> void:
	if not accepting_input:
		return
	accepting_input = false

	var pos_before := player.grid_pos
	var msg := Movement.try_move(player, dir, map, entities)
	if double_step and player.hp > 1 and player.grid_pos != pos_before:
		var second_msg := Movement.try_move(player, dir, map, entities)
		if second_msg != "":
			msg = (msg + " " + second_msg) if msg != "" else second_msg
		player.hp -= 1
		var sprint_msg := "The sprint costs you 1 HP."
		msg = (msg + " " + sprint_msg) if msg != "" else sprint_msg

	if msg != "":
		message_logged.emit(msg)
	_cleanup_dead()
	if player.hp <= 0:
		player_died.emit()
		return

	for m in entities.duplicate():
		if m == player or m.hp <= 0:
			continue
		var mmsg := MonsterAI.take_turn(m, player, map, entities)
		if mmsg != "":
			message_logged.emit(mmsg)
		if player.hp <= 0:
			_cleanup_dead()
			player_died.emit()
			return

	_cleanup_dead()
	accepting_input = true

func _cleanup_dead() -> void:
	entities = entities.filter(func(e): return e == player or e.hp > 0)
