extends Node2D

# Path vers la scène Ingredient.tscn
@export var ingredient_scene : PackedScene

# Référence à l'ingrédient actuellement présent
var current_ingredient : Node2D = null

func _process(delta: float) -> void:
	# Si aucun ingrédient présent, en créer un
	if current_ingredient == null:
		spawn_ingredient()

func spawn_ingredient() -> void:
	# Instancier l'ingrédient
	current_ingredient = ingredient_scene.instantiate()
	# Ajouter à la scène principale
	get_parent().add_child(current_ingredient)
	# Positionner sur le spawner
	current_ingredient.global_position = global_position
