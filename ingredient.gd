extends Node2D

# Propriétés
var state : String = "raw" # "raw", "chopped", "done"
var is_held : bool = false

# Fonction appelée quand le joueur interagit
func interact(action : String) -> void:
	if action == "cut" and state == "raw":
		state = "chopped"
		print("Ingredient coupé !")
