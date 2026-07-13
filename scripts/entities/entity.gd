class_name Entity
extends RefCounted

var grid_pos: Vector2i
var glyph: String
var color: Color
var hp: int
var max_hp: int
var atk: int
var display_name: String
var is_player: bool = false
var sight_radius: int = 6

var base_atk: int = 0
var base_defense: int = 0
var defense: int = 0
var weapon = null
var armor = null

var gold: int = 0
var gold_min: int = 0
var gold_max: int = 0

var heal_items_consumed: int = 0
var crit_chance: float = 0.0

var home_room: Rect2i = Rect2i()
var restrict_to_room: bool = false
var trap_immune: bool = false
var half_speed: bool = false
var resting: bool = false
var blink_hidden: bool = false

var move_steps: int = 1
var phases_walls: bool = false
var dodge_chance: float = 0.0

static func new_player(pos: Vector2i) -> Entity:
	var e := Entity.new()
	e.grid_pos = pos
	e.glyph = "@"
	e.color = Color(1, 1, 1)
	e.hp = 30
	e.max_hp = 30
	e.base_atk = 3
	e.base_defense = 0
	e.atk = e.base_atk
	e.defense = e.base_defense
	e.display_name = "you"
	e.is_player = true
	e.crit_chance = 0.06
	return e

func equip_weapon(item_def: Dictionary) -> void:
	weapon = item_def.duplicate()
	weapon["durability"] = weapon["durability_max"]
	_recompute_atk()

func equip_armor(item_def: Dictionary) -> void:
	armor = item_def.duplicate()
	armor["durability"] = armor["durability_max"]
	_recompute_defense()

func unequip_weapon() -> void:
	weapon = null
	_recompute_atk()

func unequip_armor() -> void:
	armor = null
	_recompute_defense()

func recompute_stats() -> void:
	_recompute_atk()
	_recompute_defense()

func _recompute_atk() -> void:
	atk = base_atk + (weapon["atk_bonus"] if weapon != null else 0)

func _recompute_defense() -> void:
	defense = base_defense + (armor["def_bonus"] if armor != null else 0)

static func new_monster(pos: Vector2i, def: Dictionary) -> Entity:
	var e := Entity.new()
	e.grid_pos = pos
	e.glyph = def.glyph
	e.color = def.color
	e.hp = def.hp
	e.max_hp = def.hp
	e.atk = def.atk
	e.base_defense = def.get("defense", 0)
	e.defense = e.base_defense
	e.display_name = def.name
	e.sight_radius = def.get("sight_radius", 6)
	e.gold_min = def.get("gold_min", 0)
	e.gold_max = def.get("gold_max", 0)
	e.trap_immune = def.get("trap_immune", false)
	e.half_speed = def.get("half_speed", false)
	e.move_steps = def.get("move_steps", 1)
	e.phases_walls = def.get("phases_walls", false)
	e.dodge_chance = def.get("dodge_chance", 0.0)
	e.is_player = false
	return e
