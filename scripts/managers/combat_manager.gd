extends Node2D
class_name CombatManager

# --- Variables ---
var screen_effect_layer: CanvasLayer
var screen_effect_rect: ColorRect
var player: CharacterBody2D
var enemy: CharacterBody2D
var current_state: CombatState = CombatState.ENEMY_TURN
var turn_time_remaining: float = 0.0
var turn_duration: float = 0.0
var debug_mode: bool = true

# --- Enums ---
enum CombatState { ENEMY_TURN, PLAYER_TURN }

# --- Constants ---
const TURN_DURATION = {
	"enemy": 5.0,   # How long the enemy turn lasts
	"player": .5   # Increased to 5 seconds for more decision time
}

const TIME_SCALE = {
	"bullet_time": 0.1,  # Decreased to 0.1 for more dramatic slow motion
	"normal": 1.0        # Normal speed during enemy turn
}

const TURN_COLORS = {
	"enemy": Color(1.0, 0.0, 0.0, 0.1),  # Red tint
	"player": Color(0.0, 0.0, 1.0, 0.1),  # Blue tint
	"none": Color(0.0, 0.0, 0.0, 0.0)     # Transparent
}

# --- Lifecycle Methods ---
func _ready() -> void:
	# Create screen effects if they don't exist
	setup_screen_effects()
	
	# Get references via groups
	player = get_tree().get_first_node_in_group("player")
	enemy = get_tree().get_first_node_in_group("enemy")
	
	# Add self to group for easy access from other nodes
	add_to_group("combat_manager")
	
	connect_signals()
	start_enemy_turn()

	# Add debug input map if not exists
	if not InputMap.has_action("debug_switch_turn"):
		var event = InputEventKey.new()
		event.keycode = KEY_QUOTELEFT  # This is the tilde/backtick key
		InputMap.add_action("debug_switch_turn")
		InputMap.action_add_event("debug_switch_turn", event)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_switch_turn"):
		handle_debug_input()

func _process(delta: float) -> void:
	# Use real delta time since we're no longer dealing with process modes
	if turn_time_remaining > 0:
		turn_time_remaining -= delta
		
		if turn_time_remaining <= 0:
			handle_turn_timeout()

# --- Setup Methods ---
func setup_screen_effects() -> void:
	# Create CanvasLayer if it doesn't exist
	if not has_node("ScreenEffectsLayer"):
		screen_effect_layer = CanvasLayer.new()
		screen_effect_layer.name = "ScreenEffectsLayer"
		add_child(screen_effect_layer)
	else:
		screen_effect_layer = $ScreenEffectsLayer
	
	# Create ColorRect if it doesn't exist
	if not screen_effect_layer.has_node("ScreenEffectRect"):
		screen_effect_rect = ColorRect.new()
		screen_effect_rect.name = "ScreenEffectRect"
		screen_effect_layer.add_child(screen_effect_rect)
		# Set up the color rect
		screen_effect_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		screen_effect_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		screen_effect_rect.color = TURN_COLORS.none
	else:
		screen_effect_rect = screen_effect_layer.get_node("ScreenEffectRect")

func connect_signals() -> void:
	if is_instance_valid(player):
		connect_player_signals()
	else:
		push_error("Player node not found in Combat Manager!")

func connect_player_signals() -> void:
	if not player.is_connected("action_selected", _on_player_action_selected):
		player.connect("action_selected", _on_player_action_selected)
	if not player.is_connected("player_defeated", _on_player_defeated):
		player.connect("player_defeated", _on_player_defeated)

# --- Turn Management ---
func start_enemy_turn() -> void:
	current_state = CombatState.ENEMY_TURN
	Engine.time_scale = TIME_SCALE.normal  # Resume normal time for enemy turn
	turn_duration = TURN_DURATION.enemy
	turn_time_remaining = turn_duration
	
	if screen_effect_rect:
		screen_effect_rect.color = TURN_COLORS.enemy
	
	# Notify all nodes that can handle turn start
	get_tree().call_group("player", "on_enemy_turn_start")
	get_tree().call_group("enemy", "on_enemy_turn_start")

func start_player_turn() -> void:
	current_state = CombatState.PLAYER_TURN
	Engine.time_scale = TIME_SCALE.bullet_time  # Slow motion instead of pause
	turn_duration = TURN_DURATION.player
	turn_time_remaining = turn_duration
	
	if screen_effect_rect:
		screen_effect_rect.color = TURN_COLORS.player
	
	# Changed this line to use specific turn start method
	get_tree().call_group("player", "on_player_turn_start")
	get_tree().call_group("enemy", "on_player_turn_start")

func get_turn_progress() -> float:
	if turn_duration <= 0:
		return 0.0
	return turn_time_remaining / turn_duration

# --- Signal Handlers ---
func _on_player_action_selected(_action_index: int) -> void:
	turn_time_remaining = 0  # Force turn end
	start_enemy_turn()

func _on_player_defeated() -> void:
	Engine.time_scale = TIME_SCALE.paused
	# TODO: Implement game over screen

func handle_turn_timeout() -> void:
	match current_state:
		CombatState.ENEMY_TURN:
			start_player_turn()
		CombatState.PLAYER_TURN:
			handle_player_turn_timeout()

# --- Helper Methods ---
func handle_player_turn_timeout() -> void:
	if player and player.has_method("on_player_turn_timeout"):
		player.on_player_turn_timeout()
	start_enemy_turn()

func handle_debug_input() -> void:
	match current_state:
		CombatState.ENEMY_TURN:
			turn_time_remaining = 0  # Force turn end
			start_player_turn()
		CombatState.PLAYER_TURN:
			if is_instance_valid(player) and player.has_method("_on_action_button_pressed"):
				player._on_action_button_pressed(0)
			else:
				turn_time_remaining = 0  # Force turn end
				start_enemy_turn()

# Add getter method for state
func get_current_state() -> CombatState:
	return current_state
