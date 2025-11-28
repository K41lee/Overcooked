extends Node2D

@export var plate_scene: PackedScene
@onready var spawn_point: Node2D = $SpawnPoint
var plates: Array = []

func _ready():
	for i in range(3):
		var plate = plate_scene.instantiate()
		plates.append(plate)

# Pas de réservation pour les assiettes - accès libre pour tous les agents
func give_plate(agent_id: int = -1) -> Node2D:
	if plates.size() > 0:
		return plates.pop_back()
	return null

func return_plate(plate: Node2D):
	plates.append(plate)
	
func give_ingredient(agent_id: int = -1) -> Node2D:
	var plate = plate_scene.instantiate()
	plate.z_index = 10
	get_tree().current_scene.add_child(plate)
	plate.global_position = spawn_point.global_position
	return plate
