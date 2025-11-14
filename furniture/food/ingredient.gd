extends Node2D

@export var type: String = "tomate"
var state: String = "raw"

# Reservation API (Phase A) - ingredients can also be reserved while being used
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

func _ready():
	z_index = 5  # par défaut au-dessus des tables, mais en dessous de l’assiette si posé seul


func chop():
	if state == "raw":
		state = "chopped"

func cook():
	if state in ["raw", "chopped"]:
		state = "cooked"
