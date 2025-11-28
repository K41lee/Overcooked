extends Node2D

@export var type: String = "tomate"
var state: String = "raw"

@onready var sprite: Sprite2D = null

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
	z_index = 5  # par défaut au-dessus des tables, mais en dessous de l'assiette si posé seul
	sprite = $Sprite2D


func chop():
	if state == "raw":
		state = "chopped"
		_update_sprite()

func cook():
	if state in ["raw", "chopped"]:
		state = "cooked"
		_update_sprite()

func _update_sprite():
	if sprite == null:
		return
	
	var texture_path = ""
	
	match type:
		"tomate":
			if state == "chopped":
				texture_path = "res://assets/tomate_cut.png"
			else:
				texture_path = "res://assets/Tomate.png"
		"oignon":
			if state == "chopped":
				texture_path = "res://assets/oignons_cut.png"
			else:
				texture_path = "res://assets/Oignon.png"
		"salade":
			if state == "chopped":
				texture_path = "res://assets/salade_cut.png"
			else:
				texture_path = "res://assets/Salade.png"
		"viande":
			if state == "cooked":
				texture_path = "res://assets/Viande_Cuit.png"
			elif state == "chopped":
				texture_path = "res://assets/Viande_cut.png"
			else:
				texture_path = "res://assets/Viande.png"
		"poisson":
			if state == "cooked":
				texture_path = "res://assets/Poisson_cuit.png"
			elif state == "chopped":
				texture_path = "res://assets/poisson_cut.png"
			else:
				texture_path = "res://assets/Poisson.png"
	
	if texture_path != "":
		var texture = load(texture_path)
		if texture:
			sprite.texture = texture
			print("🖼️ Changed sprite for ", type, " to state: ", state)
