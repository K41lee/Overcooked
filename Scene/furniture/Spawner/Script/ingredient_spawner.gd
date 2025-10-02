extends Node2D

@export var ingredient_scene : PackedScene   # la scène spécifique de l’ingrédient (Tomato.tscn, Lettuce.tscn, Onion.tscn)
@onready var spawn_point = $SpawnPoint

func try_give_ingredient(agent: Node) -> Node2D:
	if agent.held_item == null: # agent doit avoir les mains libres
		var ingredient = ingredient_scene.instantiate()
		get_parent().add_child(ingredient)
		ingredient.global_position = spawn_point.global_position
		agent.pickup(ingredient)
		return ingredient
	return null
