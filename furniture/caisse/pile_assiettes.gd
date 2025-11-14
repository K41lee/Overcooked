extends Node2D

@export var plate_scene: PackedScene
@onready var spawn_point: Node2D = $SpawnPoint  # Marker2D / Node2D, tout va bien
var plates: Array = []

func _ready():
	for i in range(3):
		var plate = plate_scene.instantiate()
		plates.append(plate)

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

func give_plate(agent_id: int = -1) -> Node2D:
	if reserved_by != -1 and agent_id != reserved_by:
		return null

	if plates.size() > 0:
		return plates.pop_back()
	return null

func return_plate(plate: Node2D):
	plates.append(plate)
	
func give_ingredient(agent_id: int = -1) -> Node2D:
	if reserved_by != -1 and agent_id != reserved_by:
		return null

	var plate = plate_scene.instantiate()
	plate.z_index = 10
	get_tree().current_scene.add_child(plate)
	plate.global_position = spawn_point.global_position
	return plate
