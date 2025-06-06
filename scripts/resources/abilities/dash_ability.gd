extends Ability
class_name DashAbility

@export var dash_speed: float = 500
@export var dash_duration: float = 0.2
@export var dash_invulnerability: bool = true

# Override can_use to check combat state
func can_use(player: Node2D) -> bool:
    # First check if base ability allows use
    if not super.can_use(player):
        return false
        
    # Get combat manager reference
    var combat_manager = player.combat_manager
    if not combat_manager:
        return false
        
    # Allow during enemy turn or transitions, but not during player turn
    return combat_manager.current_state == combat_manager.CombatState.ENEMY_TURN or \
           combat_manager.current_state == combat_manager.CombatState.TRANSITIONING

func _execute(player: Node2D) -> void:
    # Get dash direction from player's current input
    var input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
    if input_vector == Vector2.ZERO:
        input_vector = Vector2.RIGHT # Default direction if no input
    
    var dash_direction = input_vector.normalized()
    var tween = player.create_tween()
    
    if dash_invulnerability:
        player.set_invulnerable(true)
    
    # Perform dash movement
    tween.tween_property(player, "position", 
        player.position + dash_direction * dash_speed * dash_duration, 
        dash_duration)
    
    # Reset invulnerability after dash
    if dash_invulnerability:
        await tween.finished
        player.set_invulnerable(false)