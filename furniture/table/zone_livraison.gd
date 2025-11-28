extends Node2D

@onready var place_point: Marker2D = $PlacePoint

# Reservation API (Phase A)
var reserved_by: int = -1
var reserved_at: float = 0.0
signal reservation_changed(reserved_by)

func reserve(agent_id: int) -> bool:
	if reserved_by == -1:
		reserved_by = agent_id
		reserved_at = Time.get_ticks_msec() / 1000.0
		emit_signal("reservation_changed", reserved_by)
		print("[Reservation] ", get_path(), " reserved by agent", reserved_by)
		return true
	if reserved_by == agent_id:
		return true
	return false

func release(agent_id: int) -> void:
	if reserved_by == agent_id:
		reserved_by = -1
		reserved_at = 0.0
		emit_signal("reservation_changed", reserved_by)
	print("[Reservation] ", get_path(), " released by agent", agent_id)
func is_reserved() -> bool:
	return reserved_by != -1

func receive_ingredient(ingredient: Node2D, agent_id: int = -1) -> bool:
	# Reservation check
	if reserved_by != -1 and agent_id != reserved_by:
		return false
	
	# Vérifier si c'est une assiette avec une recette attendue
	var main_node = get_tree().current_scene
	
	if ingredient.has_method("get_ingredients"):
		# Vérifier si l'assiette a une recette attendue
		if "expected_recipe" in ingredient and not ingredient.expected_recipe.is_empty():
			var expected = ingredient.expected_recipe
			var content = ingredient.get_ingredients()
			
			# Vérifier que le contenu correspond à la recette
			if _check_recipe_match(content, expected, ingredient):
				print("✅ Recette validée :", expected.get("name", "inconnue"))
				main_node.add_score(100)
				ingredient.queue_free()
			else:
				print("❌ Mauvaise recette... Attendu:", expected.get("name", "?"))
				ingredient.queue_free()
		else:
			print("❌ Assiette sans recette attendue")
			ingredient.queue_free()
	else:
		print("❌ Ce n'est pas une assiette")
	
	return true

func _check_recipe_match(content: Array, recipe: Dictionary, plate: Node2D) -> bool:
	"""Vérifie si le contenu de l'assiette correspond à la recette attendue"""
	var needed = recipe.get("ingredients", [])
	
	# Vérifier le nombre d'ingrédients
	if content.size() != needed.size():
		return false
	
	# Vérifier chaque ingrédient
	for ing in needed:
		var found = content.any(
			func(c): return c.type == ing["type"] and c.state == ing["state"]
		)
		if not found:
			return false
	
	# Vérifier la cuisson si nécessaire
	if recipe.get("cook", false) and plate.state != "cooked":
		return false
	
	return true
