extends CharacterBody2D

enum State {IDLE, MOVING, TELEGRAPH, ATTACKING}

@export_group("Combat Properties")
@export var speed: float = 100.0
@export var stop_distance: float = 200.0
@export var attack_damage: int = 10
@export var attack_windup_time: float = 1.0
@export var max_health: int = 100
@export var idle_cooldown: float = 2.0  # Time to wait after attacking

@export_group("Debug")
@export var debug_mode: bool = true

var current_state: State = State.IDLE
var player: Node2D = null
var attacked_this_turn: bool = false
var telegraph_started: bool = false
var current_health: int
var attack_timer: Timer
var cooldown_timer: Timer
var combat_manager: Node2D

@onready var telegraph_visual: Node2D = $TelegraphVisual
@onready var attack_area: Area2D = $AttackArea

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	current_health = max_health
	
	# Setup attack timer
	attack_timer = Timer.new()
	add_child(attack_timer)
	attack_timer.name = "AttackTimer"
	attack_timer.wait_time = attack_windup_time
	attack_timer.one_shot = true
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	
	# Setup cooldown timer
	cooldown_timer = Timer.new()
	add_child(cooldown_timer)
	cooldown_timer.name = "CooldownTimer"
	cooldown_timer.wait_time = idle_cooldown
	cooldown_timer.one_shot = true
	cooldown_timer.timeout.connect(_on_cooldown_timeout)
	
	# Setup telegraph visual
	if telegraph_visual:
		telegraph_visual.hide()
	else:
		push_error("TelegraphVisual node not found!")

	if debug_mode:
		print("Stop distance: ", stop_distance)
		print("Attack windup time: ", attack_windup_time)
		
	add_to_group("enemy")
	combat_manager = get_tree().get_first_node_in_group("combat_manager")

func _physics_process(_delta: float) -> void:
	if not player or current_health <= 0:
		return
		
	match current_state:
		State.IDLE:
			handle_idle_state()
		State.MOVING:
			handle_moving_state()
		State.TELEGRAPH:
			handle_telegraph_state()
		State.ATTACKING:
			handle_attack_state()

func handle_idle_state() -> void:
	if not attacked_this_turn:
		current_state = State.MOVING

func handle_moving_state() -> void:
	var direction := global_position.direction_to(player.global_position)
	var distance := global_position.distance_to(player.global_position)
	
	#print("Distance to player: ", distance)  # Debug print
	
	if distance > stop_distance:
		velocity = direction * speed
		look_at(player.global_position)
		move_and_slide()
	else:
		velocity = Vector2.ZERO
		move_and_slide()  # Ensure we stop moving
		current_state = State.TELEGRAPH
		print("Entering telegraph state")  # Debug print

func handle_telegraph_state() -> void:
	if not telegraph_started:
		telegraph_started = true
		if telegraph_visual:
			telegraph_visual.show()
			print("Showing telegraph visual")  # Debug print
		else:
			push_error("Telegraph visual not found!")
		attack_timer.start()
		print("Started attack timer: ", attack_windup_time)  # Debug print

func handle_attack_state() -> void:
	if not attacked_this_turn and player:
		var bodies = attack_area.get_overlapping_bodies()
		for body in bodies:
			if body.is_in_group("player"):
				body.take_damage(attack_damage)
				print("Player hit by attack!")
		
		attacked_this_turn = true
		telegraph_visual.hide()
		current_state = State.IDLE
		cooldown_timer.start()  # Start cooldown after attack

func _on_attack_timer_timeout() -> void:
	telegraph_started = false
	current_state = State.ATTACKING

func _on_cooldown_timeout() -> void:
	attacked_this_turn = false  # Reset attack flag
	current_state = State.MOVING  # Start moving again

func take_damage(amount: int) -> void:
	print("Enemy taking %d damage" % amount)
	current_health -= amount
	if current_health <= 0:
		die()

func die() -> void:
	queue_free()

func on_player_turn_start() -> void:
	# Don't stop or reset enemy behavior
	# Just let it continue in slow motion
	pass

func on_enemy_turn_start() -> void:
	# Reset for new turn
	attacked_this_turn = false
	current_state = State.MOVING
