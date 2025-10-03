extends CharacterBody2D


var linear_force = 5
var posCB: Vector2
var direction
var state = "idle"
var states = ["idle","cook","move"]
var held_ingredient : Node = null
var target_node: Node = null
var pos_target: Vector2

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


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	MoveToTarget("CuttingBoard")

func MoveToTarget(target : String) -> void:
	posCB =  get_parent().get_node(target).global_position
	direction = (posCB - global_position).normalized()
	if global_position != posCB:
		velocity = direction * 150.0
		move_and_slide()
