extends Node2D

var type: String = "plate"
var ingredients: Array = []
var state: String = "raw"
var expected_recipe: Dictionary = {}  # La recette attendue pour cette assiette

@onready var place_point: Marker2D = $PlacePoint

func add_ingredient(ingredient: Node2D) -> bool:
	if ingredient.state == "raw":
		print("⚠️ Impossible de mettre un ingrédient cru dans une assiette")
		return false

	if ingredient.get_parent():
		ingredient.get_parent().remove_child(ingredient)

	add_child(ingredient)

	var offset = Vector2(0, -8 * ingredients.size())
	ingredient.position = place_point.position + offset
	ingredient.z_index = 11

	ingredients.append(ingredient)
	state = "filled"
	return true

func get_ingredients() -> Array:
	return ingredients
