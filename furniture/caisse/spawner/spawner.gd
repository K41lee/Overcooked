# spawner.gd
extends Node2D

@export var ingredient_scene: PackedScene
@onready var spawn_point: Node2D = $SpawnPoint  # Marker2D / Node2D, tout va bien

# Reservation API (Phase A)
# `reserved_by` holds the agent id that reserved this resource, -1 = free
var reserved_by: int = -1
var reserved_at: float = 0.0

signal reservation_changed(reserved_by)

func reserve(agent_id: int) -> bool:
	"""Try to reserve this resource for agent_id.
	Returns true if reservation succeeded, false otherwise."""
	if reserved_by == -1:
		reserved_by = agent_id
		reserved_at = Time.get_ticks_msec() / 1000.0
		emit_signal("reservation_changed", reserved_by)
		print("[Reservation] ", get_path(), " reserved by agent", reserved_by)
		return true
	# If already reserved by same agent, consider it a success (idempotent)
	if reserved_by == agent_id:
		return true
	return false

func release(agent_id: int) -> void:
	"""Release the reservation only if agent_id matches the holder."""
	if reserved_by == agent_id:
		reserved_by = -1
		reserved_at = 0.0
		emit_signal("reservation_changed", reserved_by)
		print("[Reservation] ", get_path(), " released by agent", agent_id)

func is_reserved() -> bool:
	return reserved_by != -1

func give_ingredient(agent_id: int = -1) -> Node2D:
	# If reserved by someone else, refuse
	if reserved_by != -1 and agent_id != reserved_by:
		return null

	var ingredient = ingredient_scene.instantiate()
	get_tree().current_scene.add_child(ingredient)
	ingredient.global_position = spawn_point.global_position
	return ingredient
