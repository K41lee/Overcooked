extends Node2D

@export var ingredient_name : String = "Generic"

var is_held : bool = false

func _process(delta: float) -> void:
	# Si l’ingrédient est tenu par un agent
	if is_held and get_parent() != null:
		# il suit automatiquement son parent (l’agent)
		position = Vector2.ZERO
