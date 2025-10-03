extends CharacterBody2D

var linear_force = 5
var posCB: Vector2
var direction
var state = "idle"
var states = ["idle","cook","move"]
var held_ingredient : Node = null
var target_node: Node = null
var pos_target: Vector2

func _physics_process(delta: float) -> void:
	MoveToTarget("SpawnerTomate")

func MoveToTarget(target : String) -> void:
	var posCB = get_parent().get_node(target).global_position
	var direction = (posCB - global_position)
	if direction.length() > 5.0:
		direction = direction.normalized()
		velocity = direction * 150.0
	else:
		Idle()
	move_and_slide()

func Idle():
	velocity = Vector2.ZERO
	request_ingredient(get_parent().get_node("SpawnerTomate"))

func request_ingredient(spawner: Node) -> void:
	if held_ingredient != null:
		print("Agent a déjà un ingrédient.")
		return
	var item = spawner.try_give_ingredient(self)
	if item != null:
		print("Agent a pris un ingrédient : ", item.name)
	else:
		print("Le spawner n’a rien donné.")

func pickup(ingredient: Node):
	held_ingredient = ingredient
	# Optionnel : attacher la tomate au Cuisinier
	ingredient.position = Vector2.ZERO
	add_child(ingredient)
	print("Agent a pris un ingrédient : ", ingredient.name)
