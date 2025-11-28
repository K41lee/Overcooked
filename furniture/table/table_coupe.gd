extends Node2D

var stored: Node2D = null
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
	if reserved_by != -1 and agent_id != reserved_by:
		return false

	if stored == null:
		stored = ingredient
		ingredient.get_parent().remove_child(ingredient)
		add_child(ingredient)
		ingredient.position = place_point.position

		# ✅ transformation en "chopped"
		if "state" in ingredient:
			ingredient.state = "chopped"
			print("🔪 " + ingredient.type + " a été coupé")

		return true
	return false

func give_ingredient(agent_id: int = -1) -> Node2D:
	if reserved_by != -1 and agent_id != reserved_by:
		return null

	if stored != null:
		var ing = stored
		stored = null
		remove_child(ing)
		get_tree().current_scene.add_child(ing)
		ing.global_position = place_point.global_position
		return ing
	return null
