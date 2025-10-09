extends Node2D

var stored: Node2D = null
@onready var place_point: Marker2D = $PlacePoint

func receive_ingredient(ingredient: Node2D) -> bool:
	# Si une assiette est déjà posée sur la table
	if stored != null and stored.has_method("add_ingredient"):
		return stored.add_ingredient(ingredient)

	# Sinon on pose l'objet normalement (assiette ou ingrédient seul)
	if stored == null:
		stored = ingredient
		ingredient.get_parent().remove_child(ingredient)
		add_child(ingredient)
		ingredient.position = place_point.position
		return true

	return false


func give_ingredient() -> Node2D:
	if stored != null:
		var ing = stored
		stored = null
		remove_child(ing)
		get_tree().current_scene.add_child(ing)
		ing.global_position = place_point.global_position
		return ing
	return null
