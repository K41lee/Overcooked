extends Node

# --- Liste des recettes disponibles ---
var recipe_list = [
	{
		"name": "Soupe à l'oignon",
		"type": "plate",
		"cook": true, # cuisson finale obligatoire
		"ingredients": [
			{"type": "oignon", "state": "chopped"},
			{"type": "oignon", "state": "chopped"},
			{"type": "oignon", "state": "chopped"}
		]
	},
	{
		"name": "Salade tomate",
		"type": "plate",      # nécessite une assiette
		"cook": false,        # pas de cuisson finale
		"ingredients": [
			{"type": "salade", "state": "chopped"},
			{"type": "tomate", "state": "chopped"}
		]
	},
	{
		"name": "Soupe de tomates",
		"type": "plate",
		"cook": true,
		"ingredients": [
			{"type": "tomate", "state": "chopped"},
			{"type": "tomate", "state": "chopped"},
			{"type": "tomate", "state": "chopped"}
		]
	},
	{
		"name": "Steak grillé",
		"type": "plate",
		"cook": false,   # ✅ on ne cuit pas l’assiette
		"ingredients": [
			{"type": "viande", "state": "cooked"}
		]
	},
	{
		"name": "Poisson grillé",
		"type": "plate",
		"cook": false,
		"ingredients": [
			{"type": "poisson", "state": "cooked"}
		]
	},
	{
		"name": "Brochette mixte",
		"type": "plate",
		"cook": true,
		"ingredients": [
			{"type": "viande", "state": "chopped"},
			{"type": "poisson", "state": "chopped"},
			{"type": "oignon", "state": "chopped"}
		]
	}
]

var current_recipe: Dictionary = {}

func _ready():
	set_random_recipe()


func check_plate(plate: Node2D) -> bool:
	if not plate.has_method("get_ingredients"):
		return false
	var content = plate.get_ingredients()

	if current_recipe.is_empty():
		return false

	if _matches(content, current_recipe["ingredients"]):
		# si la recette demande cuisson → vérifier l'état de l'assiette
		if current_recipe["cook"] and plate.state != "cooked":
			return false
		return true
	return false


func _matches(content: Array, needed: Array) -> bool:
	if content.size() != needed.size():
		return false
	for ing in needed:
		var found = content.any(
			func(c): return c.type == ing["type"] and c.state == ing["state"]
		)
		if not found:
			return false
	return true


func set_random_recipe() -> void:
	current_recipe = recipe_list.pick_random()


func get_current_recipe() -> Dictionary:
	return current_recipe
