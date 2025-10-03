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
