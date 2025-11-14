extends Node2D

@onready var place_point: Marker2D = $PlacePoint

# Reservation API (Phase A)
var reserved_by: int = -1
signal reservation_changed(reserved_by)

func reserve(agent_id: int) -> bool:
	if reserved_by == -1:
		reserved_by = agent_id
		emit_signal("reservation_changed", reserved_by)
		print("[Reservation] ", get_path(), " reserved by agent", reserved_by)
		return true
	if reserved_by == agent_id:
		return true
	return false

func release(agent_id: int) -> void:
	if reserved_by == agent_id:
		reserved_by = -1
		emit_signal("reservation_changed", reserved_by)
	print("[Reservation] ", get_path(), " released by agent", agent_id)
func is_reserved() -> bool:
	return reserved_by != -1

func receive_ingredient(ingredient: Node2D, agent_id: int = -1) -> bool:
	# Reservation check
	if reserved_by != -1 and agent_id != reserved_by:
		return false
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
