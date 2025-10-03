extends CharacterBody2D

var linear_force = 5
var posCB: Vector2
var direction
var state = "idle"
var states = ["idle","cook","move"]
var targets = ["SpawnerTomate","SpawnerSalade","SpawnerOignon"]
var held_ingredient : Node = null
var target_node: Node = null
var pos_target: Vector2
var IdleNoScope = 0
var test = randi_range(0,2)#tmp


# Called every frame. 'delta' is the elapsed time since the previous frame.

func _physics_process(delta: float) -> void:
	MoveToTarget(targets[test])
	

func MoveToTarget(target : String) -> void:
	var posCB = get_parent().get_node(target).global_position
	var direction = (posCB - global_position)
	# Seuil de proximité pour arrêter le mouvement (par exemple 5 pixels)
	IdleNoScope = 0
	if direction.length() > 5.0:
		$AnimatedSprite2D.animation = "walk"
		direction = direction.normalized()
		velocity = direction * 150.0
	else:
		Idle()
		
	
	move_and_slide()

func Idle():
	velocity = Vector2.ZERO
	request_ingredient(get_parent().get_node("SpawnerTomate"))

func request_ingredient(spawner: Node) -> void:
	if IdleNoScope == 0 :
		velocity = Vector2(0.0,0.0)
		$AnimatedSprite2D.animation = "idle"
		IdleNoScope = IdleNoScope + 1
		test = randi_range(0,2)#tmp
		
		
		
	

func Cook():
	velocity = Vector2.ZERO
	#quand il arrive sur une plance ou une cuisson l'agent attendra , puis il devra pickup l'item transfo


func request_ingredient(spawner: Node) -> Node:
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
