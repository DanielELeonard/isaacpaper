# Player.gd (Simplified)
extends CharacterBody2D

@export_group("Combat")
@export var max_health: int = 100
@export var base_attack_damage: int = 10

@export_group("Debug")
@export var debug_mode: bool = true

# Component references
@onready var movement_component: PlayerMovementComponent = $PlayerMovementComponent
@onready var action_manager: CombatActionManager = $CombatActionManager
@onready var radial_menu: RadialActionMenu = $UIContainer/RadialActionMenu
@onready var turn_handler: PlayerTurnHandler = $PlayerTurnHandler
@onready var ability_manager: PlayerAbilityManager = $PlayerAbilityManager
@onready var turn_timer: TextureProgressBar = $TextureProgressBar
# Core state
var current_health: int
var combat_manager: Node

signal player_defeated

func _ready() -> void:
	current_health = max_health
	add_to_group("player")
	
	# Get combat manager reference first
	combat_manager = get_tree().get_first_node_in_group("combat_manager")
	
	# Wait one frame to ensure all @onready vars are initialized
	await get_tree().process_frame
	
	# Now setup components after they're properly loaded
	setup_components()
	setup_input_mappings()

func setup_components() -> void:
	# Verify components exist before connecting them
	if not is_instance_valid(radial_menu):
		push_error("RadialActionMenu component not found!")
		return
		
	if not is_instance_valid(action_manager):
		push_error("CombatActionManager component not found!")
		return
		
	if not is_instance_valid(turn_handler):
		push_error("PlayerTurnHandler component not found!")
		return

	# Connect components to each other
	radial_menu.setup_with_action_manager(action_manager)
	radial_menu.action_selected.connect(combat_manager._on_player_action_selected)
	turn_handler.setup_components(radial_menu, action_manager)
	
	# Connect to combat manager signals
	if combat_manager:
		combat_manager.enemy_turn_started.connect(turn_handler.handle_enemy_turn_start)
		combat_manager.player_turn_started.connect(turn_handler.handle_player_turn_start)
		combat_manager.player_turn_timeout.connect(turn_handler.handle_player_turn_timeout)
		combat_manager.turn_progress_updated.connect(_on_turn_progress_updated)
		combat_manager.turn_started.connect(_on_turn_started)
	else:
		push_warning("No combat manager found!")

	# Initialize turn timer
	if turn_timer:
		turn_timer.max_value = 100
		turn_timer.min_value = 0
		turn_timer.value = 100
	else:
		push_error("Turn timer not found!")

	if debug_mode:
		print("Components setup completed")

func _physics_process(_delta: float) -> void:
	# Movement is now handled by the movement component
	update_movement_permissions()

func update_movement_permissions() -> void:
	if combat_manager:
		# Allow movement during enemy turn and transition states
		var can_move = combat_manager.current_state == combat_manager.CombatState.ENEMY_TURN or \
					  combat_manager.current_state == combat_manager.CombatState.TRANSITIONING
		movement_component.set_movement_enabled(can_move)

func take_damage(amount: int) -> void:
	if debug_mode:
		print("Player taking %d damage" % amount)
	
	current_health -= amount
	
	if current_health <= 0:
		die()

func die() -> void:
	if debug_mode:
		print("Player defeated")
	emit_signal("player_defeated")

func setup_input_mappings() -> void:
	# Movement input mappings
	var movement_actions = ["move_left", "move_right", "move_up", "move_down"]
	var movement_keys = [KEY_A, KEY_D, KEY_W, KEY_S]
	
	for i in movement_actions.size():
		if not InputMap.has_action(movement_actions[i]):
			var event = InputEventKey.new()
			event.keycode = movement_keys[i]
			InputMap.add_action(movement_actions[i])
			InputMap.action_add_event(movement_actions[i], event)
	
	# Ability input mapping
	if not InputMap.has_action("use_active_ability"):
		var ability_event = InputEventKey.new()
		ability_event.keycode = KEY_SPACE
		InputMap.add_action("use_active_ability")
		InputMap.action_add_event("use_active_ability", ability_event)
	
	if debug_mode:
		print("Input mappings setup completed")

func _on_turn_progress_updated(progress: float) -> void:
	if not turn_timer:
		return
		
	# Skip updating timer during transition state
	if combat_manager.current_state == combat_manager.CombatState.TRANSITIONING:
		return
		
	var percentage = progress * 100
	turn_timer.value = percentage
	
	# Update timer color based on progress
	var warning_threshold = 30
	if percentage <= warning_threshold:
		turn_timer.modulate = Color(1.0, 0.2, 0.2) # Red when time is running out
	else:
		turn_timer.modulate = Color(1.0, 1.0, 1.0) # Normal color

func _on_turn_started(turn_type: int, duration: float) -> void:
	if not turn_timer:
		return
	
	# Ignore transition state for timer visibility
	if turn_type == combat_manager.CombatState.TRANSITIONING:
		return
		
	# Show timer only during enemy turn (counting down to player turn)
	turn_timer.visible = turn_type == combat_manager.CombatState.ENEMY_TURN
	
	if turn_timer.visible:
		turn_timer.value = 100 # Reset to full
		turn_timer.modulate = Color(1.0, 1.0, 1.0) # Reset color
