extends Node2D

var stored: Node2D = null
@onready var place_point: Marker2D = $PlacePoint

func receive_ingredient(ingredient: Node2D) -> bool:
	if stored == null:
		stored = ingredient
		ingredient.get_parent().remove_child(ingredient)
		add_child(ingredient)
		ingredient.position = place_point.position

		# ✅ transformation en "cooked"
		if "state" in ingredient:
			ingredient.state = "cooked"
			print("🔥 " + ingredient.type + " a été cuit")

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
