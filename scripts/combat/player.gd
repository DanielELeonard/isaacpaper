extends CharacterBody2D

const BasicAttackResource = preload("res://resources/actions/basic_attack.gd")
const DefendActionResource = preload("res://resources/actions/basic_defend.gd")
const DashAbilityResource = preload("res://resources/abilities/dash_ability.gd")


# --- Exports ---
@export_group("Movement")
@export var move_speed: float = 200.0

@export_group("Combat")
@export var max_health: int = 100
@export var base_attack_damage: int = 10

@export_group("UI")
@export var ui_offset: Vector2 = Vector2.ZERO
@export var ui_circle_radius: float = 150.0

@export_group("Debug")
@export var debug_mode: bool = true

# --- Onready Variables ---
@onready var player_ui_container: Control = $ActionButtonsContainer
@onready var turn_progress_bar: TextureProgressBar = $TextureProgressBar
@onready var combat_manager: Node = get_tree().get_first_node_in_group("combat_manager")
@onready var enemy_node: Node2D = get_tree().get_first_node_in_group("enemy")
@onready var action_buttons_container: Control = $ActionButtonsContainer

# --- Variables ---
var current_health: int
var abilities: Array[DashAbilityResource] = []  # Add type hint
var active_ability: DashAbilityResource  # Add type hint
var equipment_slots: Dictionary = {
	"weapon": null,
	"armor": null,
	"active_item": null
}

var base_stats: Dictionary = {
	"max_health": 100,
	"move_speed": 200.0,
	"damage": 10,
	"defense": 0
}

var current_stats: Dictionary = {}
var is_invulnerable: bool = false
var combat_actions: Array = []
var default_actions: Array = []

const ActionButtonResource = preload("res://resources/ui/action_button.gd")

# --- Signals ---
signal action_selected(action_index: int)
signal player_defeated

func _ready() -> void:
	current_health = max_health
	setup_default_actions()
	setup_ui()
	
	# Make sure we're in the player group
	add_to_group("player")

	# Initialize current stats
	current_stats = base_stats.duplicate()

	# Create and add dash ability
	var dash = DashAbilityResource.new()
	dash.ability_name = "Quick Dash"
	dash.cooldown = 1.0
	dash.can_use_in_enemy_turn = true
	dash.description = "Quickly dash in the movement direction"
	abilities.append(dash)
	active_ability = dash
	
	# Add input map if not exists
	if not InputMap.has_action("use_active_ability"):
		var event = InputEventKey.new()
		event.keycode = KEY_SPACE
		InputMap.add_action("use_active_ability")
		InputMap.action_add_event("use_active_ability", event)
	
	# Add movement input mappings if they don't exist
	var movement_actions = ["move_left", "move_right", "move_up", "move_down"]
	var movement_keys = [KEY_A, KEY_D, KEY_W, KEY_S]
	
	for i in movement_actions.size():
		if not InputMap.has_action(movement_actions[i]):
			var event = InputEventKey.new()
			event.keycode = movement_keys[i]
			InputMap.add_action(movement_actions[i])
			InputMap.action_add_event(movement_actions[i], event)
	
	# Setup default actions
	setup_default_actions()
	
	# Initialize UI with available actions
	setup_combat_ui()

func _physics_process(_delta: float) -> void:
	handle_movement()
	update_progress_bar()

func _process(delta: float) -> void:
	# Update ability cooldowns
	if active_ability:
		active_ability.update_cooldown(delta)
	
	# Check for active ability input during enemy turn only
	if is_instance_valid(combat_manager):
		var is_enemy_turn = combat_manager.get_current_state() == combat_manager.CombatState.ENEMY_TURN
		if is_enemy_turn and Input.is_action_just_pressed("use_active_ability"):
			handle_active_ability_input()
			if debug_mode:
				print("Dash input detected, can use: ", active_ability.can_use(self))

# --- Movement ---
func handle_movement() -> void:
	# Get input direction
	var input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	# Check if we can move (only during enemy turn)
	var can_move = false
	if is_instance_valid(combat_manager):
		can_move = combat_manager.current_state == combat_manager.CombatState.ENEMY_TURN
	
	# Apply movement
	if can_move and input_vector != Vector2.ZERO:
		velocity = input_vector * move_speed
	else:
		velocity = Vector2.ZERO
	
	move_and_slide()

func handle_active_ability_input() -> void:
	if Input.is_action_just_pressed("use_active_ability"):
		if active_ability and active_ability.can_use(self):
			if debug_mode:
				print("Using dash ability")
			active_ability.use(self)

# --- Combat ---
func take_damage(amount: int) -> void:
	if is_invulnerable:
		if debug_mode:
			print("Player is invulnerable - damage ignored")
		return
	
	if debug_mode:
		print("Player taking %d damage" % amount)
	
	current_health -= amount
	
	if debug_mode:
		print("Player health: %d/%d" % [current_health, max_health])
	
	if current_health <= 0:
		die()

func die() -> void:
	if debug_mode:
		print("Player defeated")
	emit_signal("player_defeated")

func modify_stat(stat_name: String, amount: float) -> void:
	if stat_name in current_stats:
		current_stats[stat_name] += amount
		_on_stats_changed()

func _on_stats_changed() -> void:
	# Update dependent values
	max_health = current_stats.max_health
	move_speed = current_stats.move_speed

# --- UI Setup and Management ---
func setup_ui() -> void:
	if not is_instance_valid(player_ui_container):
		push_error("Player UI Container not found!")
		return
		
	# Setup UI container
	player_ui_container.visible = false
	player_ui_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_ui_container.position = ui_offset
	
	# Setup progress bar
	if is_instance_valid(turn_progress_bar):
		setup_progress_bar()
	
	connect_ui_button_signals()
	position_ui_elements_relative()

func setup_progress_bar() -> void:
	turn_progress_bar.max_value = 1.0
	turn_progress_bar.value = 0.0
	turn_progress_bar.visible = false

func update_progress_bar() -> void:
	if not is_instance_valid(turn_progress_bar) or not is_instance_valid(combat_manager):
		return
		
	var is_turn_active = combat_manager.current_state in [
		combat_manager.CombatState.ENEMY_TURN,
		combat_manager.CombatState.PLAYER_TURN
	]
	
	turn_progress_bar.visible = is_turn_active
	if not is_turn_active:
		turn_progress_bar.value = 0.0
		return
	
	var progress = calculate_turn_progress()
	# Remove debug print
	turn_progress_bar.value = progress

func calculate_turn_progress() -> float:
	if not is_instance_valid(combat_manager):
		return 0.0
		
	var progress = combat_manager.get_turn_progress()
	var is_enemy_turn = combat_manager.current_state == combat_manager.CombatState.ENEMY_TURN
	
	# Enemy turn fills up, player turn empties
	return (1.0 - progress) if is_enemy_turn else progress

func position_ui_elements_relative() -> void:
	var buttons = get_ui_buttons()
	if buttons.is_empty():
		return
		
	var angle_step = 360.0 / buttons.size()
	var current_angle = 0.0
	
	for button in buttons:
		var offset = Vector2(
			ui_circle_radius * cos(deg_to_rad(current_angle)),
			ui_circle_radius * sin(deg_to_rad(current_angle))
		)
		button.position = offset - (button.size / 2.0)
		current_angle += angle_step

# --- Turn Management ---
func on_enemy_turn_start() -> void:
	if debug_mode:
		print("Enemy turn started - Hiding UI")
	player_ui_container.visible = false
	player_ui_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_buttons_container.visible = false

func on_player_turn_start() -> void:
	if debug_mode:
		print("Player turn started - Showing UI")
	player_ui_container.visible = true
	player_ui_container.mouse_filter = Control.MOUSE_FILTER_PASS
	position_ui_elements_relative()
	action_buttons_container.visible = true

func on_player_turn_timeout() -> void:
	if debug_mode:
		print("Player turn timed out")
	player_ui_container.visible = false
	player_ui_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_buttons_container.visible = false

# --- Action Handling ---
func setup_default_actions() -> void:
	var attack = BasicAttackResource.new()
	var defend = DefendActionResource.new()
	
	default_actions = [attack, defend]
	combat_actions = default_actions.duplicate()
	
	if debug_mode:
		print("Default actions setup: ", [attack.action_name, defend.action_name])

func setup_combat_ui() -> void:
	# Clear existing buttons
	for child in action_buttons_container.get_children():
		child.queue_free()
	
	# Set container properties
	action_buttons_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Create buttons in a circle
	var button_count = combat_actions.size()
	for i in button_count:
		var action = combat_actions[i]
		
		# Create the action button directly
		var button = ActionButton.new()
		button.setup(action, i)
		
		# Position in circle
		var angle = (2 * PI * i) / button_count - (PI / 2)  # Start from top
		var pos = Vector2(
			cos(angle) * ui_circle_radius,
			sin(angle) * ui_circle_radius
		) + ui_offset
		
		# Set button position (centered)
		button.position = pos - (button.BUTTON_SIZE / 2)
		button.pressed.connect(_on_action_button_pressed.bind(i))
		
		action_buttons_container.add_child(button)
	
	# Show UI only during player turn
	action_buttons_container.visible = false

func add_combat_action(action: CombatAction) -> void:
	combat_actions.append(action)
	setup_combat_ui()  # Use setup_combat_ui instead of update_action_ui

func _on_action_button_pressed(index: int) -> void:
	if not is_instance_valid(combat_manager):
		return
	
	if index >= combat_actions.size():
		return
	
	var action = combat_actions[index]
	var target = get_tree().get_first_node_in_group("enemy")
	
	if action.can_use(self, target):
		action.execute(self, target)
		emit_signal("action_selected", index)

func check_active_ability_input() -> void:
	if Input.is_action_just_pressed("use_active_ability"):
		if active_ability and active_ability.can_use(self):
			if debug_mode:
				print("Using dash ability")
			active_ability.use(self)

# --- Helper Functions ---
func get_ui_buttons() -> Array:
	var buttons = []
	for child in player_ui_container.get_children():
		if child is Button:
			buttons.append(child)
	return buttons

func connect_ui_button_signals() -> void:
	for i in get_ui_buttons().size():
		var button = get_ui_buttons()[i]
		if button.is_connected("pressed", _on_action_button_pressed):
			button.disconnect("pressed", _on_action_button_pressed)
		button.connect("pressed", _on_action_button_pressed.bind(i))

func set_invulnerable(value: bool) -> void:
	is_invulnerable = value
	modulate = Color(1, 1, 1, 0.5) if is_invulnerable else Color(1, 1, 1, 1)
