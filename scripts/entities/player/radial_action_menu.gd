# RadialActionMenu.gd
class_name RadialActionMenu
extends Control

@export var menu_radius: float = 150.0
@export var start_angle_degrees: float = 45.0
@export var end_angle_degrees: float = 315.0
@export var button_scale: float = 1.0

signal action_selected(action_index: int)

var action_buttons: Array[ActionButton] = []
var action_manager: CombatActionManager
var is_menu_active: bool = false

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func setup_with_action_manager(manager: CombatActionManager) -> void:
	action_manager = manager
	action_manager.actions_changed.connect(_on_actions_changed)
	_on_actions_changed()  # Initial setup

func _on_actions_changed() -> void:
	clear_existing_buttons()
	create_action_buttons()
	position_buttons_with_constraints()

func clear_existing_buttons() -> void:
	for button in action_buttons:
		button.queue_free()
	action_buttons.clear()

func create_action_buttons() -> void:
	var action_count = action_manager.get_action_count()
	
	for i in range(action_count):
		var action = action_manager.get_action(i)
		var button = ActionButton.new()
		button.setup(action, i)
		button.scale = Vector2(button_scale, button_scale)
		button.pressed.connect(_on_action_button_pressed.bind(i))
		
		add_child(button)
		action_buttons.append(button)

func position_buttons_with_constraints() -> void:
	var button_count = action_buttons.size()
	if button_count == 0:
		return
	
	var start_angle = deg_to_rad(start_angle_degrees)
	var end_angle = deg_to_rad(end_angle_degrees)
	var arc_span = calculate_arc_span(start_angle, end_angle)
	
	if button_count == 1:
		var middle_angle = start_angle + (arc_span / 2.0)
		position_button_at_angle(action_buttons[0], middle_angle)
	else:
		var angle_step = arc_span / (button_count - 1)
		for i in range(button_count):
			var angle = start_angle + (i * angle_step)
			position_button_at_angle(action_buttons[i], angle)

func calculate_arc_span(start_angle: float, end_angle: float) -> float:
	# Handle cases where the arc crosses the 0/360 degree boundary
	if end_angle < start_angle:
		return (2.0 * PI) - start_angle + end_angle
	else:
		return end_angle - start_angle

func position_button_at_angle(button: ActionButton, angle: float) -> void:
	var position = Vector2(
		cos(angle) * menu_radius,
		sin(angle) * menu_radius
	)
	button.position = position - (button.size / 2.0)

func show_menu() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	is_menu_active = true

func hide_menu() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	is_menu_active = false

func _on_action_button_pressed(action_index: int) -> void:
	emit_signal("action_selected", action_index)
