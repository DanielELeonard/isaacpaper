# CombatActionManager.gd
class_name CombatActionManager
extends Node

signal action_executed(action: CombatAction, target: Node)
signal actions_changed

var available_actions: Array[CombatAction] = []
var default_actions: Array[CombatAction] = []

func _ready() -> void:
	setup_default_actions()

func setup_default_actions() -> void:
	var attack = BasicAttack.new()
	var defend = BasicDefendAction.new()
	
	default_actions = [attack, defend]
	available_actions = default_actions.duplicate()
	emit_signal("actions_changed")

func add_action(action: CombatAction) -> void:
	available_actions.append(action)
	emit_signal("actions_changed")

func remove_action(action: CombatAction) -> void:
	var index = available_actions.find(action)
	if index >= 0:
		available_actions.remove_at(index)
		emit_signal("actions_changed")

func execute_action(action_index: int, user: Node, target: Node = null) -> bool:
	if action_index < 0 or action_index >= available_actions.size():
		return false
	
	var action = available_actions[action_index]
	if not action.can_use(user, target):
		return false
	
	action.execute(user, target)
	emit_signal("action_executed", action, target)
	return true

func get_action_count() -> int:
	return available_actions.size()

func get_action(index: int) -> CombatAction:
	if index >= 0 and index < available_actions.size():
		return available_actions[index]
	return null
