extends Node2D

var state : String = "raw"
var is_held : bool = false
var holder : Node = null  # Le joueur qui porte cet ingrédient
var spawner : Node = null  # Le spawner qui a généré cet ingrédient

func interact(action : String) -> void:
	if action == "cut" and state == "raw":
		state = "chopped"
		print("Ingredient coupé !")

func pick_up():
	is_held = true
	# Informer le spawner qu'il n'y a plus d'ingrédient ici
	if spawner != null:
		spawner.current_ingredient = null
		spawner = null

func _physics_process(delta: float) -> void:
	if is_held and holder != null:
		# Suivre le joueur
		global_position = holder.global_position
