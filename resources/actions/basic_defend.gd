extends "res://resources/actions/combat_action.gd"
class_name BasicDefendAction

@export var defense_multiplier: float = 1.5
@export var defense_duration: float = 2.0
@export var shield_vfx_scene: PackedScene  # For visual shield effect

var is_defending: bool = false

func _init() -> void:
    action_name = "Defend"
    description = "Take reduced damage for a short time"
    is_default = true
    animation_name = "defend"  # If we add animations later

func can_use(_actor: Node2D, _target: Node2D) -> bool:
    return not is_defending

func _perform_action(actor: Node2D, _target: Node2D) -> void:
    if not actor.has_method("modify_stat"):
        push_error("Actor cannot modify stats!")
        return
    
    is_defending = true
    
    # Apply defense buff
    var defense_boost = actor.base_stats.defense * (defense_multiplier - 1.0)
    actor.modify_stat("defense", defense_boost)
    
    # Visual feedback
    _spawn_shield_effect(actor)
    
    # Create timer for defense duration
    var timer = Timer.new()
    actor.add_child(timer)
    timer.wait_time = defense_duration
    timer.one_shot = true
    
    # Connect timeout to remove defense
    timer.timeout.connect(func():
        actor.modify_stat("defense", -defense_boost)
        is_defending = false
        timer.queue_free()
        if actor.has_method("on_defend_end"):
            actor.on_defend_end()
    )
    
    timer.start()
    
    # Notify actor defense started
    if actor.has_method("on_defend_start"):
        actor.on_defend_start()

func _spawn_shield_effect(actor: Node2D) -> void:
    if shield_vfx_scene:
        var shield = shield_vfx_scene.instantiate()
        actor.add_child(shield)
        
        # Remove shield when defense ends
        var timer = Timer.new()
        shield.add_child(timer)
        timer.wait_time = defense_duration
        timer.one_shot = true
        timer.timeout.connect(func(): shield.queue_free())
        timer.start()