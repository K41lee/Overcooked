extends Node2D

@onready var place_point: Marker2D = $PlacePoint

func receive_ingredient(ingredient: Node2D) -> bool:
	# Vérifier si c’est une assiette et si elle correspond à la recette
	var main_node = get_tree().current_scene
	var recipes = main_node.recipes

	if ingredient.has_method("get_ingredients") and recipes.check_plate(ingredient):
		print("✅ Recette validée :", ingredient.type)
		main_node.add_score(100)

		# Supprimer l’assiette (livrée)
		ingredient.queue_free()

		# Lancer une nouvelle recette
		main_node._start_new_recipe()
	else:
		print("❌ Mauvaise recette...")
	return true
