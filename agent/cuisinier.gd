extends CharacterBody2D

@export var speed: float = 200.0

var held_ingredient: Node2D = null
@onready var hand_point: Marker2D = $HandPoint
@onready var action_label: Label = $ActionLabel

var target: Node2D = null
var action: String = ""
var interact_range: float = 16.0

var action_queue: Array = []
var is_busy: bool = false
@export var action_delay: float = 1.0
@export var cut_time: float = 6.0
@export var cook_time: float = 10.0

func _physics_process(delta: float) -> void:
	if target != null:
		var dir = (target.global_position - global_position)
		if dir.length() > interact_range:
			velocity = dir.normalized() * speed
		else:
			velocity = Vector2.ZERO
			_perform_action()
			target = null
			action = ""
			is_busy = false

			var t = get_tree().create_timer(0.1)
			await t.timeout
			_process_next_action()
	else:
		velocity = Vector2.ZERO

	move_and_slide()


# ---------------------------
# ACTIONS DE BASE
# ---------------------------

func pickup(target_name: String) -> void:
	var node: Node2D = null
	if target_name in ["tomate", "salade", "oignon", "viande", "poisson"]:
		node = _find_node("Spawner" + target_name.capitalize())
	else:
		node = _find_node(target_name)

	if node:
		# ✅ Messages spécifiques + update label
		if held_ingredient == null:
			if target_name in ["tomate", "salade", "oignon", "viande", "poisson"]:
				print("🚶 Agent: go to the " + target_name + " box")
				_update_label("Va chercher " + target_name)
			elif target_name == "PileAssiettes":
				print("🚶 Agent: go to the plate stack")
				_update_label("Va chercher une assiette")

		print("🎯 Agent: pickup " + target_name)
		_start_action(node, "pickup")
	else:
		print("⚠️ Pickup impossible, noeud non trouvé : " + target_name)


func drop(station: String) -> void:
	var node = _find_node(station)
	if node:
		print("🎯 Agent: drop on " + station)
		_start_action(node, "drop")


func deliver() -> void:
	var node = _find_node("ZoneLivraison")
	if node:
		print("🎯 Agent: deliver plate")
		_start_action(node, "deliver")


# ---------------------------
# FILE D’ACTIONS
# ---------------------------

func queue_actions(actions: Array) -> void:
	for act in actions:
		action_queue.append(act)
	if not is_busy:
		_process_next_action()


func _process_next_action() -> void:
	if action_queue.size() > 0:
		var next = action_queue.pop_front()
		print("➡️ Prochaine action: ", next)
		var act = next[0]
		var arg = next[1] if next.size() > 1 else ""

		# ✅ attendre action_delay avant d'enchaîner
		await get_tree().create_timer(action_delay).timeout

		match act:
			"pickup":
				pickup(arg)
			"drop":
				drop(arg)
			"deliver":
				deliver()
	else:
		print("✅ Agent: toutes les actions sont terminées !")
		_update_label("Idle")


# ---------------------------
# EXÉCUTION D’UNE ACTION
# ---------------------------
func _clean_name(node: Node) -> String:
	var name = node.name

	# Si c'est un spawner → "tomate", "oignon", "salade"
	if name.begins_with("Spawner"):
		return name.substr(7).to_lower()

	# Si c'est une table de travail numérotée → "table de travail"
	if name.begins_with("TableTravail"):
		return "table de travail"

	# TableCoupe → "table de coupe"
	if name.begins_with("TableCoupe"):
		return "table de coupe"

	# Fourneau → "fourneau"
	if name.begins_with("Fourneau"):
		return "fourneau"

	# PileAssiettes → "pile d’assiettes"
	if name.begins_with("PileAssiettes"):
		return "pile d’assiettes"

	# ZoneLivraison → "zone de livraison"
	if name.begins_with("ZoneLivraison"):
		return "zone de livraison"

	# Par défaut → nom brut en minuscule
	return name.to_lower()

func _start_action(node: Node2D, act: String) -> void:
	target = node
	action = act
	is_busy = true

	# Déterminer ce qu’on tient
	var obj = ""
	if held_ingredient != null and "type" in held_ingredient:
		obj = held_ingredient.type

	# Nettoyer le nom du node
	var clean_name = _clean_name(node)

	# Mettre à jour le label
	match act:
		"pickup":
			if obj == "":
				_update_label("Va chercher " + clean_name)
			else:
				_update_label("Va chercher " + obj)
		"drop":
			if target.name.begins_with("TableCoupe"):
				_update_label("Va couper " + obj)
			elif target.name.begins_with("Fourneau"):
				_update_label("Va faire cuire " + obj)
			elif "stored" in target and target.stored != null and target.stored.has_method("add_ingredient"):
				_update_label("Va poser " + obj + " dans l’assiette")
			else:
				_update_label("Va poser " + obj + " sur " + clean_name)
		"deliver":
			_update_label("Va servir " + (obj if obj != "" else "plat") + " à la " + clean_name)

func _perform_action() -> void:
	# ----- PICKUP -----
	if action == "pickup" and held_ingredient == null and target and target.has_method("give_ingredient"):
		held_ingredient = target.give_ingredient()
		if held_ingredient:
			held_ingredient.get_parent().remove_child(held_ingredient)
			hand_point.add_child(held_ingredient)
			held_ingredient.position = Vector2.ZERO

			var label = "objet"
			if "type" in held_ingredient:
				label = held_ingredient.type

			print("👉 Agent: a ramassé " + label)

			_update_label("Prend " + label)
			await get_tree().create_timer(action_delay).timeout
			_update_label("Tient " + label)
			await get_tree().create_timer(action_delay).timeout


	# ----- DROP -----
	elif action == "drop" and held_ingredient != null:
		var obj = "objet"
		if "type" in held_ingredient:
			obj = held_ingredient.type

		if target and target.has_method("receive_ingredient"):
			if target.receive_ingredient(held_ingredient):
				print("👉 Agent: a déposé " + obj)
				hand_point.remove_child(held_ingredient)
				held_ingredient = null

				# ----- Cas : TableCoupe -----
				if target.name.begins_with("TableCoupe"):
					var station = target
					_update_label("Coupe " + obj)
					await get_tree().create_timer(cut_time).timeout

					if station and station.has_method("give_ingredient"):
						var ing = station.give_ingredient()
						if ing:
							if ing.get_parent():
								ing.get_parent().remove_child(ing)
							hand_point.add_child(ing)
							ing.position = Vector2.ZERO
							held_ingredient = ing
							_update_label("Tient " + obj)
							await get_tree().create_timer(action_delay).timeout

				# ----- Cas : Fourneau -----
				elif target.name.begins_with("Fourneau"):
					var station = target
					_update_label("Cuit " + obj)
					await get_tree().create_timer(cook_time).timeout

					if station and station.has_method("give_ingredient"):
						var ing2 = station.give_ingredient()
						if ing2:
							if ing2.get_parent():
								ing2.get_parent().remove_child(ing2)
							hand_point.add_child(ing2)
							ing2.position = Vector2.ZERO
							held_ingredient = ing2
							_update_label("Tient " + obj)
							await get_tree().create_timer(action_delay).timeout

				# ----- Cas : simple table -----
				else:
					_update_label("Pose " + obj)
					await get_tree().create_timer(action_delay).timeout
					_update_label("Déposé " + obj)
					await get_tree().create_timer(action_delay).timeout


	# ----- DELIVER -----
	elif action == "deliver" and held_ingredient != null and target and target.has_method("receive_ingredient"):
		var obj = "plat"
		if "type" in held_ingredient:
			obj = held_ingredient.type

		if target.receive_ingredient(held_ingredient):
			print("🚚 Agent: a livré " + obj)
			hand_point.remove_child(held_ingredient)

			_update_label("Livre " + obj)
			await get_tree().create_timer(action_delay).timeout
			_update_label("Servi " + obj)
			await get_tree().create_timer(action_delay).timeout

			held_ingredient = null


# ---------------------------
# CONSTRUCTION D’UNE RECETTE
# ---------------------------

func make_recipe(recipe: Dictionary, table: String = "TableTravail1") -> void:
	var actions: Array = []

	# 1. Prendre une assiette et la poser sur une table
	actions.append(["pickup", "PileAssiettes"])
	actions.append(["drop", table])

	# 2. Préparer chaque ingrédient
	for ing in recipe["ingredients"]:
		var t = ing["type"]
		var s = ing["state"]

		actions.append(["pickup", t])

		if s == "chopped":
			actions.append(["drop", "TableCoupe"])
			actions.append(["pickup", "TableCoupe"])

		if s == "cooked" and (not recipe.has("cook") or recipe["cook"] == false):
			actions.append(["drop", "Fourneau"])
			actions.append(["pickup", "Fourneau"])

		actions.append(["drop", table])  # déposer l’ingrédient dans l’assiette

	# 3. Quand tous les ingrédients sont posés
	if recipe.has("cook") and recipe["cook"]:
		# Cuisson finale de l’assiette
		actions.append(["pickup", table])
		actions.append(["drop", "Fourneau"])
		actions.append(["pickup", "Fourneau"])
	else:
		# ✅ sinon on reprend l’assiette seulement maintenant
		actions.append(["pickup", table])

	# 4. Livraison
	actions.append(["deliver"])



	print("🍳 Agent prépare automatiquement : " + recipe["name"])
	queue_actions(actions)


# ---------------------------
# UTILS
# ---------------------------

func _find_node(name: String) -> Node2D:
	var root = get_tree().current_scene
	if root.has_node(name):
		return root.get_node(name)

	for child in root.get_children():
		if child.name.to_lower() == name.to_lower():
			return child
	return null


func _update_label(text: String) -> void:
	action_label.text = text
