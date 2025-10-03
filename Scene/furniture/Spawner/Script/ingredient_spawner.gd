extends Node2D

@export var ingredient_scene : PackedScene
@onready var spawn_point = $SpawnPoint

func try_give_ingredient(agent: Node) -> Node2D:
	if agent.held_ingredient == null:
		var ingredient = ingredient_scene.instantiate()
		get_parent().add_child(ingredient)
		print(self.global_position)
		print(spawn_point.global_position)
		ingredient.global_position = spawn_point.global_position
		print(ingredient.global_position)
		agent.pickup(ingredient)
		return ingredient
	return null
