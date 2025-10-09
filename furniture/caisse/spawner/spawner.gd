# spawner.gd
extends Node2D

@export var ingredient_scene: PackedScene
@onready var spawn_point: Node2D = $SpawnPoint  # Marker2D / Node2D, tout va bien

func give_ingredient() -> Node2D:
	var ingredient = ingredient_scene.instantiate()
	get_tree().current_scene.add_child(ingredient)
	ingredient.global_position = spawn_point.global_position
	return ingredient
