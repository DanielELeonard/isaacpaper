extends Node2D
class_name CombatManager

# --- Signals ---
# These signals allow other parts of your game to react to combat events
# without the combat manager needing to know about those systems directly
signal turn_started(turn_type: CombatState, duration: float)
signal turn_ended(turn_type: CombatState)
signal combat_state_changed(new_state: CombatState, old_state: CombatState)
signal turn_progress_updated(progress: float)
signal enemy_turn_started
signal player_turn_started
signal player_turn_timeout

# --- Variables ---
var screen_effect_layer: CanvasLayer
var screen_effect_rect: ColorRect
var player: CharacterBody2D
var enemy: CharacterBody2D
var current_state: CombatState = CombatState.SETUP
var previous_state: CombatState = CombatState.SETUP
var turn_time_remaining: float = 0.0
var turn_duration: float = 0.0
var debug_mode: bool = true
var is_combat_paused: bool = false

# Track original time scale so we can restore it properly
var original_time_scale: float = 1.0

# Tween for smooth transitions
var time_scale_tween: Tween
var screen_effect_tween: Tween

# --- Enums ---
enum CombatState {
	SETUP, # Initial state before combat begins
	ENEMY_TURN,
	PLAYER_TURN,
	TRANSITIONING, # Brief state between turns for animations/effects
	PAUSED, # Combat is paused (menus, etc.)
	ENDED # Combat has concluded
}

# --- Configuration Dictionary ---
# Using a dictionary makes it easier to tweak values and add new turn types
var combat_config = {
	"turn_durations": {
		CombatState.ENEMY_TURN: 5.0,
		CombatState.PLAYER_TURN: 3.0,
		CombatState.TRANSITIONING: 0.1 # Changed from 0.5 to 0.1 for faster transitions
	},
	"time_scales": {
		CombatState.ENEMY_TURN: 1.0,
		CombatState.PLAYER_TURN: 0.05,
		CombatState.TRANSITIONING: 0.15,
		CombatState.PAUSED: 0.0
	},
	"transition_durations": {
		"time_scale": 0.15, # Changed from 0.3 to 0.1
		"screen_color": 0.15, # Changed from 0.2 to 0.1
		"fast_transition": 0.05 # Changed from 0.1 to 0.05
	},
	"screen_colors": {
		CombatState.ENEMY_TURN: Color(1.0, 0.0, 0.0, 0.1),
		CombatState.PLAYER_TURN: Color(0.0, 0.0, 1.0, 0.1),
		CombatState.TRANSITIONING: Color(1.0, 1.0, 0.0, 0.05), # Subtle yellow
		CombatState.SETUP: Color(0.0, 0.0, 0.0, 0.0),
		CombatState.PAUSED: Color(0.0, 0.0, 0.0, 0.3), # Darker overlay
		CombatState.ENDED: Color(0.0, 0.0, 0.0, 0.0)
	}
}

# --- Lifecycle Methods ---
func _ready() -> void:
	# Store the original time scale so we can restore it when combat ends
	original_time_scale = Engine.time_scale
	
	# Create tweens for smooth transitions - these will handle all our
	# smooth animations for time scale and visual effects
	time_scale_tween = create_tween()
	screen_effect_tween = create_tween()
	
	# Set tweens to not auto-start so we can control them manually
	time_scale_tween.stop()
	screen_effect_tween.stop()
	
	setup_screen_effects()
	setup_node_references()
	setup_debug_input()
	
	# Add self to group for easy access from other nodes
	add_to_group("combat_manager")
	
	# Wait a frame to ensure all nodes are ready before starting combat
	await get_tree().process_frame
	initialize_combat()

func _input(event: InputEvent) -> void:
	if debug_mode and event.is_action_pressed("debug_switch_turn"):
		handle_debug_input()

func _process(delta: float) -> void:
	# Only process turn timer for states that have time limits
	if _should_process_timer() and turn_time_remaining > 0:
		turn_time_remaining -= delta
		
		# Emit progress signal for UI updates (health bars, timers, etc.)
		var progress = get_turn_progress()
		turn_progress_updated.emit(progress)
		
		if turn_time_remaining <= 0:
			handle_turn_timeout()

# --- Setup Methods ---
func setup_screen_effects() -> void:
	"""Creates the visual overlay system for combat state feedback"""
	# Create CanvasLayer if it doesn't exist
	screen_effect_layer = _get_or_create_child(CanvasLayer, "ScreenEffectsLayer")
	
	# Create ColorRect if it doesn't exist
	screen_effect_rect = _get_or_create_child(ColorRect, "ScreenEffectRect", screen_effect_layer)
	
	# Configure the screen effect rectangle
	screen_effect_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_effect_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_effect_rect.color = combat_config.screen_colors[CombatState.SETUP]

func setup_node_references() -> void:
	"""Safely gets references to player and enemy nodes"""
	player = get_tree().get_first_node_in_group("player")
	enemy = get_tree().get_first_node_in_group("enemy")
	
	if not is_instance_valid(player):
		push_error("Combat Manager: Player node not found in 'player' group!")
		return
	
	if not is_instance_valid(enemy):
		push_warning("Combat Manager: Enemy node not found in 'enemy' group!")
	
	connect_entity_signals()

func setup_debug_input() -> void:
	"""Sets up debug input mapping if it doesn't already exist"""
	if not InputMap.has_action("debug_switch_turn"):
		var event = InputEventKey.new()
		event.keycode = KEY_QUOTELEFT # Backtick key
		InputMap.add_action("debug_switch_turn")
		InputMap.action_add_event("debug_switch_turn", event)

func connect_entity_signals() -> void:
	"""Connects to player and enemy signals with error checking"""
	if is_instance_valid(player):
		# Use callable syntax for better type safety
		if player.has_signal("action_selected") and not player.is_connected("action_selected", _on_player_action_selected):
			player.action_selected.connect(_on_player_action_selected)
		
		if player.has_signal("player_defeated") and not player.is_connected("player_defeated", _on_player_defeated):
			player.player_defeated.connect(_on_player_defeated)

# --- Combat Flow Methods ---
func initialize_combat() -> void:
	"""Starts the combat sequence"""
	change_state(CombatState.ENEMY_TURN)

func change_state(new_state: CombatState) -> void:
	"""Central method for all state changes - ensures consistency"""
	if new_state == current_state:
		return # No change needed
	
	var old_state = current_state
	previous_state = current_state
	current_state = new_state
	
	# Apply the configuration for this state
	_apply_state_config(new_state)
	
	# Emit signals for other systems to react
	combat_state_changed.emit(new_state, old_state)
	
	# Handle specific state logic
	match new_state:
		CombatState.ENEMY_TURN:
			_start_turn(new_state, "enemy")
		CombatState.PLAYER_TURN:
			_start_turn(new_state, "player")
		CombatState.TRANSITIONING:
			_start_transition()
		CombatState.PAUSED:
			_pause_combat()
		CombatState.ENDED:
			_end_combat()

func _apply_state_config(state: CombatState) -> void:
	"""Applies visual and timing configuration for a combat state with smooth transitions"""
	print("Combat Manager: Applying config for state: %s" % CombatState.keys()[state])
	
	# Handle time scale transitions smoothly
	if state in combat_config.time_scales:
		var target_time_scale = combat_config.time_scales[state]
		var current_time_scale = Engine.time_scale
		
		# Only tween if there's actually a change to make
		if abs(target_time_scale - current_time_scale) > 0.01:
			_transition_time_scale(target_time_scale, state)
	
	# Handle screen color transitions smoothly
	if screen_effect_rect and state in combat_config.screen_colors:
		var target_color = combat_config.screen_colors[state]
		var current_color = screen_effect_rect.color
		
		# Only tween if there's a meaningful color change
		if not target_color.is_equal_approx(current_color):
			_transition_screen_color(target_color, state)
	
	# Set turn duration and timer (this doesn't need to be tweened)
	if state in combat_config.turn_durations:
		turn_duration = combat_config.turn_durations[state]
		turn_time_remaining = turn_duration

func _transition_time_scale(target_scale: float, state: CombatState) -> void:
	"""Smoothly transitions the time scale with appropriate timing based on the transition type"""
	# Kill any existing time scale tween to prevent conflicts
	if time_scale_tween.is_valid():
		time_scale_tween.kill()
	
	# Create a new tween for this transition
	time_scale_tween = create_tween()
	
	# Choose transition duration based on what kind of change this is
	var transition_duration: float
	
	# Entering bullet time should feel dramatic - slightly slower transition
	if target_scale < 0.5 and Engine.time_scale >= 0.5:
		transition_duration = combat_config.transition_durations.time_scale
		print("Combat Manager: Entering bullet time over %.1f seconds" % transition_duration)
	
	# Exiting bullet time should feel energizing - faster transition
	elif target_scale >= 0.5 and Engine.time_scale < 0.5:
		transition_duration = combat_config.transition_durations.fast_transition
		print("Combat Manager: Exiting bullet time over %.1f seconds" % transition_duration)
	
	# Other transitions use standard timing
	else:
		transition_duration = combat_config.transition_durations.fast_transition
	
	# Use EASE_OUT for a more natural feeling transition
	# This starts fast and slows down, which feels more organic than linear
	time_scale_tween.tween_property(Engine, "time_scale", target_scale, transition_duration)
	time_scale_tween.set_ease(Tween.EASE_OUT)
	time_scale_tween.set_trans(Tween.TRANS_QUART) # Smooth mathematical curve

func _transition_screen_color(target_color: Color, state: CombatState) -> void:
	"""Smoothly transitions the screen overlay color"""
	# Kill any existing screen effect tween to prevent conflicts
	if screen_effect_tween.is_valid():
		screen_effect_tween.kill()
	
	# Create a new tween for this transition
	screen_effect_tween = create_tween()
	
	var transition_duration = combat_config.transition_durations.screen_color
	
	# Use EASE_IN_OUT for color transitions - this feels most natural for visual changes
	screen_effect_tween.tween_property(screen_effect_rect, "color", target_color, transition_duration)
	screen_effect_tween.set_ease(Tween.EASE_IN_OUT)
	screen_effect_tween.set_trans(Tween.TRANS_SINE) # Gentle sine wave transition

func _start_turn(state: CombatState, entity_type: String) -> void:
	"""Generic turn start logic"""
	print("Combat Manager: Starting %s turn" % entity_type)
	
	# Emit specific turn signals
	if entity_type == "enemy":
		enemy_turn_started.emit()
	elif entity_type == "player":
		player_turn_started.emit()
	
	# Notify all relevant entities about the turn start
	get_tree().call_group(entity_type, "on_%s_turn_start" % entity_type)
	get_tree().call_group("combat_entities", "on_turn_start", state)
	
	# Emit signal for UI and other systems
	turn_started.emit(state, turn_duration)

func _start_transition() -> void:
	"""Handles the brief transition state between turns"""
	print("Combat Manager: Transitioning between turns")
	
	# After transition time, move to the next appropriate state
	await get_tree().create_timer(turn_duration).timeout
	
	# Determine next state based on previous state
	match previous_state:
		CombatState.ENEMY_TURN:
			change_state(CombatState.PLAYER_TURN)
		CombatState.PLAYER_TURN:
			change_state(CombatState.ENEMY_TURN)
		_:
			change_state(CombatState.ENEMY_TURN) # Default fallback

func _pause_combat() -> void:
	"""Pauses combat while maintaining state"""
	is_combat_paused = true
	print("Combat Manager: Combat paused")

func _end_combat() -> void:
	"""Cleanly ends combat and restores normal game state with smooth transitions"""
	print("Combat Manager: Combat ended")
	
	# Smoothly restore original time scale instead of snapping back
	if time_scale_tween.is_valid():
		time_scale_tween.kill()
	
	time_scale_tween = create_tween()
	time_scale_tween.tween_property(Engine, "time_scale", original_time_scale,
		combat_config.transition_durations.time_scale)
	time_scale_tween.set_ease(Tween.EASE_OUT)
	time_scale_tween.set_trans(Tween.TRANS_QUART)
	
	# Fade out screen effects smoothly
	if screen_effect_rect:
		if screen_effect_tween.is_valid():
			screen_effect_tween.kill()
		
		screen_effect_tween = create_tween()
		screen_effect_tween.tween_property(screen_effect_rect, "color", Color.TRANSPARENT,
			combat_config.transition_durations.screen_color)
		screen_effect_tween.set_ease(Tween.EASE_OUT)

# --- Signal Handlers ---
func _on_player_action_selected(action_index: int) -> void:
	"""Player has selected an action - end their turn"""
	print("Combat Manager: Player selected action %d" % action_index)
	if current_state == CombatState.PLAYER_TURN:
		turn_ended.emit(current_state)
		change_state(CombatState.TRANSITIONING)
	else:
		push_warning("Combat Manager: Action selected while not in player turn!")

func _on_player_defeated() -> void:
	"""Handle player defeat"""
	print("Combat Manager: Player defeated!")
	change_state(CombatState.ENDED)
	# You can emit a signal here for game over screens, etc.

func handle_turn_timeout() -> void:
	"""Handles when a turn's time runs out"""
	print("Combat Manager: Turn timeout for state: %s" % CombatState.keys()[current_state])
	turn_ended.emit(current_state)
	
	match current_state:
		CombatState.ENEMY_TURN:
			change_state(CombatState.TRANSITIONING)
		CombatState.PLAYER_TURN:
			_handle_player_timeout()
		CombatState.TRANSITIONING:
			# This shouldn't normally happen, but handle gracefully
			change_state(CombatState.ENEMY_TURN)

# --- Helper Methods ---
func _handle_player_timeout() -> void:
	"""Specific logic for when player runs out of time"""
	player_turn_timeout.emit()
	if player and player.has_method("on_player_turn_timeout"):
		player.on_player_turn_timeout()
	change_state(CombatState.TRANSITIONING)

func _should_process_timer() -> bool:
	"""Determines if we should be counting down the turn timer"""
	return current_state in [CombatState.ENEMY_TURN, CombatState.PLAYER_TURN, CombatState.TRANSITIONING] and not is_combat_paused

func _get_or_create_child(type: Variant, node_name: String, parent: Node = self) -> Node:
	"""Helper method to get an existing child or create it if it doesn't exist"""
	if parent.has_node(node_name):
		return parent.get_node(node_name)
	else:
		var new_node = type.new()
		new_node.name = node_name
		parent.add_child(new_node)
		return new_node

# --- Public Interface Methods ---
func get_turn_progress() -> float:
	"""Returns how much of the current turn is remaining (0.0 to 1.0)"""
	if turn_duration <= 0:
		return 0.0
	return turn_time_remaining / turn_duration

func get_current_state() -> CombatState:
	"""Returns the current combat state"""
	return current_state

func pause_combat() -> void:
	"""Public method to pause combat"""
	if current_state != CombatState.PAUSED:
		change_state(CombatState.PAUSED)

func resume_combat() -> void:
	"""Public method to resume combat"""
	if current_state == CombatState.PAUSED:
		is_combat_paused = false
		change_state(previous_state)

func end_combat() -> void:
	"""Public method to end combat"""
	change_state(CombatState.ENDED)

func modify_turn_duration(state: CombatState, new_duration: float) -> void:
	"""Allows runtime modification of turn durations"""
	combat_config.turn_durations[state] = new_duration
	
	# If we're currently in this state, update the remaining time proportionally
	if current_state == state and turn_duration > 0:
		var progress = get_turn_progress()
		turn_duration = new_duration
		turn_time_remaining = turn_duration * progress

func trigger_dramatic_slowdown(target_scale: float = 0.05, duration: float = 0.5) -> void:
	"""Public method for other systems to trigger dramatic slow motion effects
	   Useful for special abilities, critical hits, or cinematic moments"""
	if time_scale_tween.is_valid():
		time_scale_tween.kill()
	
	time_scale_tween = create_tween()
	time_scale_tween.tween_property(Engine, "time_scale", target_scale, duration)
	time_scale_tween.set_ease(Tween.EASE_OUT)
	time_scale_tween.set_trans(Tween.TRANS_EXPO) # More dramatic curve for special effects

func restore_normal_time_scale(duration: float = 0.3) -> void:
	"""Public method to restore time scale to current state's normal value
	   Useful after special dramatic effects"""
	var target_scale = combat_config.time_scales.get(current_state, 1.0)
	_transition_time_scale(target_scale, current_state)

func set_screen_flash(color: Color, duration: float = 0.1) -> void:
	"""Public method for other systems to trigger screen flashes
	   Useful for damage effects, special abilities, etc."""
	if not screen_effect_rect:
		return
	
	# Store the current target color so we can return to it
	var return_color = combat_config.screen_colors.get(current_state, Color.TRANSPARENT)
	
	if screen_effect_tween.is_valid():
		screen_effect_tween.kill()
	
	screen_effect_tween = create_tween()
	
	# Flash to the new color quickly, then fade back to normal
	screen_effect_tween.tween_property(screen_effect_rect, "color", color, duration * 0.3)
	screen_effect_tween.tween_property(screen_effect_rect, "color", return_color, duration * 0.7)
	screen_effect_tween.set_ease(Tween.EASE_OUT)

# --- Debug Methods ---
func handle_debug_input() -> void:
	"""Debug method to manually switch turns"""
	if not debug_mode:
		return
	
	print("Combat Manager: Debug turn switch triggered")
	
	match current_state:
		CombatState.ENEMY_TURN:
			change_state(CombatState.PLAYER_TURN)
		CombatState.PLAYER_TURN:
			# Simulate player action selection
			if is_instance_valid(player) and player.has_method("_on_action_button_pressed"):
				player._on_action_button_pressed(0)
			else:
				change_state(CombatState.TRANSITIONING)
		CombatState.TRANSITIONING:
			change_state(CombatState.ENEMY_TURN)
		_:
			change_state(CombatState.ENEMY_TURN)

func get_debug_info() -> Dictionary:
	"""Returns debug information about the combat state"""
	return {
		"current_state": CombatState.keys()[current_state],
		"previous_state": CombatState.keys()[previous_state],
		"turn_time_remaining": turn_time_remaining,
		"turn_duration": turn_duration,
		"turn_progress": get_turn_progress(),
		"is_paused": is_combat_paused,
		"time_scale": Engine.time_scale
	}
