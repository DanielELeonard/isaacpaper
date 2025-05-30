# PlayerTurnHandler.gd
class_name PlayerTurnHandler
extends Node

signal turn_action_completed(action_index: int)

var radial_menu: RadialActionMenu
var action_manager: CombatActionManager
var combat_manager: Node

func _ready() -> void:
	combat_manager = get_tree().get_first_node_in_group("combat_manager")

func setup_components(menu: RadialActionMenu, actions: CombatActionManager) -> void:
	radial_menu = menu
	action_manager = actions
	
	radial_menu.action_selected.connect(_on_action_selected)

func handle_enemy_turn_start() -> void:
	radial_menu.hide_menu()

func handle_player_turn_start() -> void:
	radial_menu.show_menu()

func handle_player_turn_timeout() -> void:
	radial_menu.hide_menu()

func _on_action_selected(action_index: int) -> void:
	var player = get_parent()
	var target = get_tree().get_first_node_in_group("enemy")
	
	if action_manager.execute_action(action_index, player, target):
		radial_menu.hide_menu()
		emit_signal("turn_action_completed", action_index)
