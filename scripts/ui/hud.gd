class_name Hud
extends Control

signal move_pressed(dir: Vector2i)
signal move_released(dir: Vector2i)
signal restart_pressed
signal share_pressed
signal download_pressed

@onready var level_label: Label = $Sidebar/LevelLabel
@onready var hp_label: Label = $Sidebar/HPLabel
@onready var gold_label: Label = $Sidebar/GoldLabel
@onready var atk_label: Label = $Sidebar/AtkLabel
@onready var def_label: Label = $Sidebar/DefLabel
@onready var weapon_label: Label = $Sidebar/WeaponLabel
@onready var armor_label: Label = $Sidebar/ArmorLabel
@onready var message_log: RichTextLabel = $Sidebar/MessageLog
@onready var game_over_panel: Panel = $GameOverPanel
@onready var max_level_label: Label = $GameOverPanel/MaxLevelLabel

@onready var up_button: Button = $Sidebar/MobileControls/UpButton
@onready var down_button: Button = $Sidebar/MobileControls/DownButton
@onready var left_button: Button = $Sidebar/MobileControls/LeftButton
@onready var right_button: Button = $Sidebar/MobileControls/RightButton
@onready var restart_button: Button = $GameOverPanel/RestartButton
@onready var share_button: Button = $GameOverPanel/ShareButton
@onready var download_button: Button = $GameOverPanel/DownloadButton
@onready var screenshot_status_label: Label = $GameOverPanel/ScreenshotStatusLabel

@onready var victory_panel: Panel = $VictoryPanel
@onready var victory_names_label: Label = $VictoryPanel/ScoreNamesLabel
@onready var victory_values_label: Label = $VictoryPanel/ScoreValuesLabel
@onready var victory_restart_button: Button = $VictoryPanel/RestartButton
@onready var victory_share_button: Button = $VictoryPanel/ShareButton
@onready var victory_download_button: Button = $VictoryPanel/DownloadButton
@onready var victory_screenshot_status_label: Label = $VictoryPanel/ScreenshotStatusLabel

func _ready() -> void:
	_bind_move_button(up_button, Vector2i(0, -1))
	_bind_move_button(down_button, Vector2i(0, 1))
	_bind_move_button(left_button, Vector2i(-1, 0))
	_bind_move_button(right_button, Vector2i(1, 0))
	restart_button.pressed.connect(func(): restart_pressed.emit())
	share_button.pressed.connect(func(): share_pressed.emit())
	download_button.pressed.connect(func(): download_pressed.emit())
	victory_restart_button.pressed.connect(func(): restart_pressed.emit())
	victory_share_button.pressed.connect(func(): share_pressed.emit())
	victory_download_button.pressed.connect(func(): download_pressed.emit())

func _bind_move_button(button: Button, dir: Vector2i) -> void:
	button.button_down.connect(func(): move_pressed.emit(dir))
	button.button_up.connect(func(): move_released.emit(dir))

func update_level(level: int, max_level: int) -> void:
	level_label.text = "Floor: %d (Max %d)" % [level, max_level]

func update_hp(hp: int, max_hp: int) -> void:
	hp_label.text = "HP: %d/%d" % [hp, max_hp]

func update_gold(gold: int) -> void:
	gold_label.text = "Gold: %d" % gold

func update_gear(atk: int, defense: int, weapon, armor) -> void:
	atk_label.text = "Offense: %d" % atk
	def_label.text = "Defense: %d" % defense
	weapon_label.text = _gear_text("Weapon", weapon)
	armor_label.text = _gear_text("Armor", armor)

func _gear_text(label: String, item) -> String:
	if item == null:
		return "%s: none" % label
	return "%s: %s (%d/%d)" % [label, item["name"], item["durability"], item["durability_max"]]

func add_message(text: String) -> void:
	message_log.append_text(text + "\n")

func show_game_over(max_level: int) -> void:
	max_level_label.text = "Max Floor Reached: %d" % max_level
	screenshot_status_label.text = ""
	game_over_panel.visible = true

## score is a Dictionary shaped like {"total": int, "lines": [[label, value], ...]}
## (see main.gd's _compute_score). Names and values are rendered as two
## separate labels (left/right-aligned, one line per row) so the columns line
## up cleanly regardless of font metrics, instead of relying on tab stops.
func show_victory(score: Dictionary) -> void:
	var names: PackedStringArray = ["Total Score", ""]
	var values: PackedStringArray = [str(score["total"]), ""]
	for entry in score["lines"]:
		names.append(entry[0])
		values.append(str(entry[1]))
	victory_names_label.text = "\n".join(names)
	victory_values_label.text = "\n".join(values)
	victory_screenshot_status_label.text = ""
	victory_panel.visible = true

func show_screenshot_status(text: String) -> void:
	screenshot_status_label.text = text
	victory_screenshot_status_label.text = text

func reset() -> void:
	game_over_panel.visible = false
	victory_panel.visible = false
	screenshot_status_label.text = ""
	victory_screenshot_status_label.text = ""
	message_log.clear()
