extends CharacterBody2D

const SPEED = 100.0
const JUMP_VELOCITY = -250.0
const ATTACK_MOVEMENT_MULTIPLIER = 0.31  # Updated multiplier to slow down movement during attack
const ATTACK_SLOWDOWN_FRAME_THRESHOLD = 2.65  # Updated slowdown threshold
const ATTACK_RESET_TIME = 1.5  # Time in seconds to reset the attack sequence
const HOLD_THRESHOLD_TIME = 1.0  # Time in seconds to determine if the attack is held
const BASIC_ATTACK_4_FORCE_FRAME = 5  # The frame at which basic_attack_4 must be completed

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_reset_timer: Timer = $AttackResetTimer  # Reference to the timer node
@onready var hold_timer: Timer = $HoldTimer  # Reference to the hold timer node

var is_attacking = false
var next_attack_is_first = true  # Boolean to alternate between attack animations
var attack_queued = false  # Flag to store if an attack input was queued during the current attack
var is_holding_attack = false  # Flag to track if the attack button is being held
var must_finish_attack_4 = false  # Flag to force completion of basic_attack_4

func _ready():
	if attack_reset_timer == null or hold_timer == null:
		print("Error: Timers not found!")
	else:
		attack_reset_timer.stop()  # Ensure the timers are stopped initially
		hold_timer.stop()
		attack_reset_timer.connect("timeout", Callable(self, "_on_AttackResetTimer_timeout"))
		hold_timer.connect("timeout", Callable(self, "_on_HoldTimer_timeout"))

func _physics_process(delta: float) -> void:
	# Add gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump
	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_attacking:
		velocity.y = JUMP_VELOCITY

	# Handle attack (initial press)
	if Input.is_action_just_pressed("basic_attack"):
		if not is_attacking:
			# Start basic_attack_4 for the first 2 frames and start the hold timer
			play_holding_attack_start()
			hold_timer.start(HOLD_THRESHOLD_TIME)
		else:
			# If already attacking, queue the next attack to chain smoothly
			attack_queued = true
		return

	# Handle attack hold (continued hold)
	if Input.is_action_pressed("basic_attack"):
		return  # Continue playing basic_attack_4 if held

	# Handle attack release (after the hold timer has started)
	if Input.is_action_just_released("basic_attack") and hold_timer.is_stopped() == false and not must_finish_attack_4:
		if hold_timer.time_left > 0:
			# If released before 1 second, switch to the normal attack sequence
			play_next_attack()
		hold_timer.stop()

	# Check for the 5th frame of basic_attack_4
	if animated_sprite.animation == "basic_attack_4" and animated_sprite.frame >= BASIC_ATTACK_4_FORCE_FRAME:
		must_finish_attack_4 = true  # Force the completion of basic_attack_4

	# Handle movement even during basic_attack_4
	handle_movement()

	# Apply movement
	move_and_slide()

# Function to handle character movement
func handle_movement():
	var direction := Input.get_axis("move_left", "move_right")
	
	# Allow movement during basic_attack_4
	if is_attacking and animated_sprite.animation == "basic_attack_4":
		velocity.x = direction * SPEED
		return

	# Determine if we should apply movement slowdown
	var speed_multiplier = 1.0
	if is_attacking and should_slow_down_attack():
		speed_multiplier = ATTACK_MOVEMENT_MULTIPLIER

	# Flip the sprite depending on direction
	if direction > 0:
		animated_sprite.flip_h = false
	elif direction < 0:
		animated_sprite.flip_h = true

	# Play movement animations only when not attacking
	if not is_attacking:
		if is_on_floor():
			if direction == 0:
				animated_sprite.play("idle")
			else:
				animated_sprite.play("run")
		else:
			animated_sprite.play("jump")

	# Apply horizontal movement with multiplier
	if direction != 0:
		velocity.x = direction * SPEED * speed_multiplier
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

# Function to play the holding attack start (basic_attack_4 for the first 2 frames)
func play_holding_attack_start():
	animated_sprite.play("basic_attack_4")
	is_attacking = true
	attack_queued = false  # Reset the attack queue flag
	must_finish_attack_4 = false  # Reset the force completion flag
	print("Holding attack started!")  # Debug print

# Function to handle the hold timer timeout (key held for more than 1 second)
func _on_HoldTimer_timeout():
	print("Holding attack continued!")  # Debug print
	is_holding_attack = true  # Continue playing basic_attack_4
	hold_timer.stop()  # Stop the hold timer

# Function to play the next attack animation in the normal sequence
func play_next_attack():
	if next_attack_is_first:
		animated_sprite.play("basic_attack")
	else:
		animated_sprite.play("basic_attack_2")
	
	# Toggle for the next attack
	next_attack_is_first = not next_attack_is_first
	
	is_attacking = true
	attack_queued = false  # Reset the attack queue flag
	
	# Restart the timer to track time between attacks
	attack_reset_timer.start(ATTACK_RESET_TIME)
	print("Attack started!")  # Debug print

# This function will be triggered when an animation finishes
func _on_AnimatedSprite2D_animation_finished():
	print("Animation finished: ", animated_sprite.animation)  # Debug print
	if animated_sprite.animation == "basic_attack_4" and (is_holding_attack or must_finish_attack_4):
		is_attacking = false
		is_holding_attack = false  # Reset the holding attack flag
		must_finish_attack_4 = false  # Reset the force completion flag
		animated_sprite.play("idle")  # Go back to idle animation after basic_attack_4
		print("Holding attack finished!")  # Debug print
	elif animated_sprite.animation in ["basic_attack", "basic_attack_2"]:
		is_attacking = false
		# If an attack is queued, immediately chain the next attack
		if attack_queued:
			play_next_attack()  # Chain attacks without returning to idle
		else:
			print("Attack ended!")  # Debug print

# Function to reset the attack sequence
func _on_AttackResetTimer_timeout():
	print("Attack sequence reset due to inactivity.")
	next_attack_is_first = true  # Reset to the first attack

# Function to check if we should slow down during attack
func should_slow_down_attack() -> bool:
	# Get the total frame count of the current animation
	var total_frames = animated_sprite.sprite_frames.get_frame_count(animated_sprite.animation)
	
	# Check if we're in the last few frames (based on threshold)
	if animated_sprite.frame >= total_frames - ATTACK_SLOWDOWN_FRAME_THRESHOLD:
		return true
	return false
