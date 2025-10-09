extends Node2D

@export var type: String = "tomate"
var state: String = "raw"

func _ready():
	z_index = 5  # par défaut au-dessus des tables, mais en dessous de l’assiette si posé seul


func chop():
	if state == "raw":
		state = "chopped"

func cook():
	if state in ["raw", "chopped"]:
		state = "cooked"
