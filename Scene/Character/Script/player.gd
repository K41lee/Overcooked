extends CharacterBody2D

@export var speed : float = 200
var held_ingredient : Node = null
#toward
func _physics_process(delta: float) -> void:
	#move_toward()
	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	input_vector.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	input_vector = input_vector.normalized()
	
	velocity = input_vector * speed
	move_and_slide()

	if Input.is_action_just_pressed("ui_accept") and held_ingredient == null:
		pickup_ingredient()

func pickup_ingredient():
	for body in $PickupArea.get_overlapping_bodies():
		if body.is_in_group("Ingredients") and not body.is_held:
			body.is_held = true
			body.holder = self  # On indique que le joueur le tient
			held_ingredient = body
			break
