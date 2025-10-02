extends CharacterBody2D

@export var speed : float = 200
var held_ingredient : Node = null

# ---------------------------------------------------
# Pickup depuis un spawner (agent demande l’ingrédient)
func request_ingredient(spawner: Node) -> Node:
	if held_ingredient != null:
		print("Agent a déjà un ingrédient.")
		return null

	var item = spawner.try_give_ingredient(self)
	if item != null:
		print("Agent a pris un ingrédient : ", item.name)
	else:
		print("Le spawner n’a rien donné.")
	return item

# ---------------------------------------------------
# Pickup depuis le sol / zone autour du joueur
func pickup_ingredient():
	for body in $PickupArea.get_overlapping_bodies():
		if body.is_in_group("Ingredients") and not body.is_held:
			body.is_held = true
			body.holder = self
			held_ingredient = body
			print("Agent a ramassé : ", body.name)
			break

# ---------------------------------------------------
# Déposer l’ingrédient à une position donnée
func drop_ingredient(drop_position: Vector2):
	if held_ingredient != null:
		held_ingredient.is_held = false
		held_ingredient.holder = null
		held_ingredient.global_position = drop_position
		print("Agent a déposé : ", held_ingredient.name)
		held_ingredient = null

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
