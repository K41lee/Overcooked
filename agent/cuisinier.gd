extends CharacterBody2D

@export var speed: float = 200.0
@onready var anim = $AnimatedSprite2D
@export var agent_id: int = 0

# Retry/backoff configuration (Phase C.1)
@export var retry_initial_backoff: float = 0.5
@export var retry_multiplier: float = 2.0
@export var retry_max_backoff: float = 4.0
@export var retry_max_retries: int = 5
@export var action_timeout: float = 30.0

# Navigation anti-collision
@export var agent_avoidance_radius: float = 40.0
@export var agent_avoidance_force: float = 100.0


var held_ingredient: Node2D = null
@onready var hand_point: Marker2D = $HandPoint
@onready var action_label: Label = $ActionLabel
@onready var agent_manager = null

var target: Node2D = null
var action: String = ""
var interact_range: float = 16.0

# Hold semantics: track reserved resource during movement
var held_reservation: Node2D = null  # Resource reserved and held during movement

# Cancellation API: track action IDs for selective cancellation
var next_action_id: int = 0
signal action_cancelled(action_id, reason)
signal recipe_completed()  # Émis quand toutes les actions d'une recette sont terminées

var action_queue: Array = []
var is_busy: bool = false
var current_action_entry = null
var current_recipe: Dictionary = {}  # Recette en cours de préparation
var is_animation_locked: bool = false
@export var action_delay: float = 1.0
@export var cut_time: float = 6.0
@export var cook_time: float = 10.0

func _physics_process(delta: float) -> void:
	if target != null and is_busy:
		var dir = (target.global_position - global_position)
		if dir.length() > interact_range:
			# Moving towards target — reservation held in held_reservation
			var desired_velocity = dir.normalized() * speed
			
			# Évitement des autres agents
			var avoidance = _calculate_agent_avoidance()
			velocity = desired_velocity + avoidance
			
			# Limiter la vitesse pour ne pas dépasser speed
			if velocity.length() > speed:
				velocity = velocity.normalized() * speed
			
		else:
			# Reached target — perform action (async)
			velocity = Vector2.ZERO
			is_busy = false  # Prevent re-triggering during async action
			_perform_action()  # This will call _process_next_action() when done
			return
	else:
		velocity = Vector2.ZERO
	update_anim()
	move_and_slide()

func _ready() -> void:
	# Find an AgentManager in the current scene if present. Do NOT preload/create one here.
	agent_manager = null
	var scene = null
	if get_tree() != null:
		scene = get_tree().current_scene
	if scene:
		agent_manager = scene.get_node_or_null("AgentManager")
	if agent_manager == null:
		print("Agent: no AgentManager found in scene; operating without central manager (no preload)")

	# Register ourselves if manager supports it
	if agent_manager and agent_manager.has_method("register_agent"):
		agent_manager.register_agent(self)
	
	# Petit délai aléatoire au démarrage pour désynchroniser les agents
	await get_tree().create_timer(randf() * 0.3).timeout

func _exit_tree() -> void:
	if agent_manager and agent_manager.has_method("unregister_agent"):
		agent_manager.unregister_agent(self)


# ---------------------------
# ACTIONS DE BASE
# ---------------------------

func pickup(target_name: String) -> void:
	var node: Node2D = null
	# Prefer AgentManager selection + reservation if available
	if agent_manager and agent_manager.has_method("get_nearest_free_and_reserve"):
		if target_name in ["tomate", "salade", "oignon", "viande", "poisson"]:
			var group_name = "Spawner" + target_name.capitalize()
			node = agent_manager.get_nearest_free_and_reserve(group_name, global_position, agent_id)
			# fallback to direct lookup if manager couldn't resolve the spawner
			if node == null:
				node = _find_node("Spawner" + target_name.capitalize())
		else:
			# try using the name as a group, fallback to raw node lookup
			node = agent_manager.get_nearest_free_and_reserve(target_name, global_position, agent_id)
			if node == null:
				node = _find_node(target_name)
	else:
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

		# If AgentManager was used, it's already reserved. Otherwise try to reserve directly.
		if not (agent_manager and agent_manager.has_method("get_nearest_free_and_reserve")):
			if node.has_method("reserve"):
					if not node.reserve(agent_id):
						print("⚠️ Can't reserve ", node.name, " — deferring with backoff")
						await _requeue_with_backoff_for("pickup", target_name)
						return
		
		print("🎯 Agent: pickup " + target_name)
		# Mark this resource as held during movement
		held_reservation = node
		_start_action(node, "pickup")
	else:
		print("⚠️ Pickup impossible, noeud non trouvé : " + target_name)


func drop(station: String) -> void:
	var node = null
	# Use AgentManager to find and reserve station if available
	if agent_manager and agent_manager.has_method("get_nearest_free_and_reserve"):
		node = agent_manager.get_nearest_free_and_reserve(station, global_position, agent_id)
		if node == null:
			# Try fallback: direct node lookup + direct reserve
			var direct = _find_node(station)
			if direct:
				if direct.has_method("reserve"):
					if direct.reserve(agent_id):
						node = direct
					else:
						print("AgentManager fallback: direct node found but reserve failed for ", direct.name)
						if agent_manager and agent_manager.has_method("debug_log_reservations"):
							agent_manager.debug_log_reservations(station)
							await _requeue_with_backoff_for("drop", station)
							return
				else:
					# node exists and has no reservation API — accept it
					node = direct
			else:
						print("AgentManager: no node found via manager for '", station, "' and no direct node available — retry")
						if agent_manager and agent_manager.has_method("debug_log_reservations"):
							agent_manager.debug_log_reservations(station)
						await _requeue_with_backoff_for("drop", station)
						return
	else:
		node = _find_node(station)
		if node:
			if node.has_method("reserve"):
				if not node.reserve(agent_id):
							print("⚠️ Can't reserve ", node.name, " — deferring with backoff")
							await _requeue_with_backoff_for("drop", station)
							return

	if node:
		print("🎯 Agent: drop on " + station)
		# Mark this resource as held during movement
		held_reservation = node
		_start_action(node, "drop")


func deliver() -> void:
	var node = null
	# Prefer manager-based reservation (gives diagnostics)
	if agent_manager and agent_manager.has_method("get_nearest_free_and_reserve"):
		print("Agent: requesting AgentManager to reserve ZoneLivraison for agent", agent_id)
		node = agent_manager.get_nearest_free_and_reserve("ZoneLivraison", global_position, agent_id)
		if node == null:
			# Ask manager to print reservation table for diagnosis if available
			if agent_manager and agent_manager.has_method("debug_log_reservations"):
				agent_manager.debug_log_reservations("ZoneLivraison")
			# Try a direct fallback: find the node and attempt direct reserve (helps when groups are not set)
			var direct = _find_node("ZoneLivraison")
			if direct:
				print("Agent: AgentManager returned null — trying direct reserve on:", direct.name)
				if direct.has_method("reserve"):
					if direct.reserve(agent_id):
						node = direct
					else:
						# inspect holder and attempt to clear stale reservation if holder unknown to manager
						var holder = null
						if "reserved_by" in direct:
							holder = direct.reserved_by
							print("Agent: direct reserve failed — holder=", str(holder))
							if agent_manager and agent_manager.has_method("find_agent_by_id"):
								var hnode = agent_manager.find_agent_by_id(holder)
								if hnode == null and holder != null:
									print("Agent: holder ", str(holder), " not registered — releasing stale reservation and retrying")
									if direct.has_method('release'):
										direct.release(holder)
										if direct.reserve(agent_id):
											node = direct
									
						# if still not reserved, fallthrough to retry
				else:
					# direct node exists but has no reserve API — accept it
					node = direct
				if node == null:
							print("⚠️ Can't reserve delivery zone via AgentManager or direct fallback — retry later")
							await _requeue_with_backoff_for("deliver")
							return
			else:
				print("⚠️ Can't reserve delivery zone via AgentManager and node not found in scene — retry later")
				await _requeue_with_backoff_for("deliver")
				return
	else:
		# Manager unavailable; try direct lookup and provide rich logging
		node = _find_node("ZoneLivraison")
		if node == null:
				print("⚠️ Delivery zone node not found in scene (ZoneLivraison)")
				await _requeue_with_backoff_for("deliver")
				return
		# if node exists, inspect reservation API
		print("Agent: direct delivery node found:", node, "has reserve:", node.has_method("reserve"))
		if node.has_method("reserve"):
			# try to reserve and, if it fails, print who holds it
			if not node.reserve(agent_id):
				var holder = "unknown"
				if "reserved_by" in node:
					holder = str(node.reserved_by)
				print("⚠️ Can't reserve delivery zone — currently held by:", holder)
				if agent_manager and agent_manager.has_method("debug_log_reservations"):
					agent_manager.debug_log_reservations("ZoneLivraison")
				await _requeue_with_backoff_for("deliver")
				return

	if node:
		print("🎯 Agent: deliver plate")
		# Mark this resource as held during movement
		held_reservation = node
		_start_action(node, "deliver")


# ---------------------------
# FILE D’ACTIONS
# ---------------------------

func queue_actions(actions: Array) -> void:
	for act in actions:
		var entry = {}
		# accept either array-style ["pickup", "tomate"] or dict {'act':..., 'arg':..., 'attempts':N}
		if typeof(act) == TYPE_DICTIONARY:
			entry = act.duplicate()  # duplicate to avoid modifying original
		else:
			var a = act
			var name = a[0]
			var arg = a[1] if a.size() > 1 else ""
			entry = {'act': name, 'arg': arg, 'attempts': 0}
		
		# Assign unique ID if not already present
		if not entry.has('id'):
			entry['id'] = next_action_id
			next_action_id += 1
		
		action_queue.append(entry)
	if not is_busy:
		_process_next_action()


func _process_next_action() -> void:
	if action_queue.size() > 0:
		var next = action_queue.pop_front()
		print("➡️ Prochaine action: ", next)
		# next is a dict {'act','arg','attempts'}
		current_action_entry = next
		var act = next.get('act', "")
		var arg = next.get('arg', "")

		# attendre action_delay avant d'enchaîner
		await get_tree().create_timer(action_delay).timeout

		match act:
			"pickup":
				pickup(arg)
			"drop":
				drop(arg)
			"deliver":
				deliver()
	else:
		print("✅ Agent%d: toutes les actions sont terminées !" % agent_id)
		_update_label("Idle")
		current_recipe = {}  # Réinitialiser la recette
		recipe_completed.emit()  # Notifier main.gd


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
	is_animation_locked = false  # Déverrouiller l'animation quand on commence une nouvelle action

	# Start an action timeout monitor for this action (runs detached)
	if current_action_entry != null:
		call_deferred("_start_action_timeout_monitor", current_action_entry)

	# Déterminer ce qu'on tient
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
		# Request the ingredient, passing our agent_id when supported
		if target.has_method("give_ingredient"):
			held_ingredient = target.give_ingredient(agent_id)
		else:
			held_ingredient = target.give_ingredient()
		if held_ingredient:
			held_ingredient.get_parent().remove_child(held_ingredient)
			hand_point.add_child(held_ingredient)
			held_ingredient.position = Vector2.ZERO

			# release reservation on the source (spawner/pile) if supported
			if target and target.has_method("release"):
				target.release(agent_id)
				# Clear held_reservation after successful pickup and release
				if held_reservation == target:
					held_reservation = null

			var label = "objet"
			if "type" in held_ingredient:
				label = held_ingredient.type
			
			# Si c'est une assiette et qu'on a une recette en cours, l'assigner à l'assiette
			if label == "plate" and not current_recipe.is_empty() and "expected_recipe" in held_ingredient:
				held_ingredient.expected_recipe = current_recipe.duplicate()

			print("👉 Agent: a ramassé " + label)

			_update_label("Prend " + label)
			update_anim("idle")
			await get_tree().create_timer(action_delay).timeout
			_update_label("Tient " + label)
			await get_tree().create_timer(action_delay).timeout


	# ----- DROP -----
	elif action == "drop" and held_ingredient != null:
		var obj = "objet"
		if "type" in held_ingredient:
			obj = held_ingredient.type

		if target and target.has_method("receive_ingredient"):
			# pass agent_id when possible
			var received = false
			if target.has_method("receive_ingredient"):
				received = target.receive_ingredient(held_ingredient, agent_id)
			else:
				received = target.receive_ingredient(held_ingredient)
			
			if received:
				print("👉 Agent: a déposé " + obj)
				hand_point.remove_child(held_ingredient)
				held_ingredient = null

				# ----- Cas : TableCoupe -----
				if target.name.begins_with("TableCoupe"):
					var station = target
					_update_label("Coupe " + obj)
					is_animation_locked = true
					update_anim("cook")
					await get_tree().create_timer(cut_time).timeout
					is_animation_locked = false

					if station and station.has_method("give_ingredient"):
						var ing = station.give_ingredient(agent_id)
						if ing:
							if ing.get_parent():
								ing.get_parent().remove_child(ing)
							hand_point.add_child(ing)
							ing.position = Vector2.ZERO
							held_ingredient = ing
							_update_label("Tient " + obj)
							await get_tree().create_timer(action_delay).timeout

					# release the station reservation after retrieving (or even if nothing was returned)
					if station and station.has_method("release"):
						station.release(agent_id)
						# Clear held_reservation for cutting station
						if held_reservation == station:
							held_reservation = null

				# ----- Cas : Fourneau -----
				elif target.name.begins_with("Fourneau"):
					var station = target
					_update_label("Cuit " + obj)
					is_animation_locked = true
					update_anim("cook")
					await get_tree().create_timer(cook_time).timeout
					is_animation_locked = false

					if station and station.has_method("give_ingredient"):
						var ing2 = station.give_ingredient(agent_id)
						if ing2:
							if ing2.get_parent():
								ing2.get_parent().remove_child(ing2)
							hand_point.add_child(ing2)
							ing2.position = Vector2.ZERO
							held_ingredient = ing2
							_update_label("Tient " + obj)
							await get_tree().create_timer(action_delay).timeout

					# release the station reservation after retrieving (or even if nothing was returned)
					if station and station.has_method("release"):
						station.release(agent_id)
						# Clear held_reservation for cooking station
						if held_reservation == station:
							held_reservation = null

				# ----- Cas : simple table -----
				else:
					_update_label("Pose " + obj)
					update_anim("idle")
					await get_tree().create_timer(action_delay).timeout
					_update_label("Déposé " + obj)
					await get_tree().create_timer(action_delay).timeout
					# release reservation on simple tables if supported
					# For TableTravail we keep the reservation across multiple ingredient drops
					# so the agent can assemble the plate. Only release for other tables.
					if target and target.has_method("release") and not target.name.begins_with("TableTravail"):
						target.release(agent_id)
						# Clear held_reservation for non-TableTravail tables
						if held_reservation == target:
							held_reservation = null
					# For TableTravail, keep held_reservation active for assembly


	# ----- DELIVER -----
	elif action == "deliver" and held_ingredient != null and target and target.has_method("receive_ingredient"):
		var obj = "plat"
		if "type" in held_ingredient:
			obj = held_ingredient.type

		# pass agent_id when possible
		var received = false
		if target.has_method("receive_ingredient"):
			received = target.receive_ingredient(held_ingredient, agent_id)
		else:
			received = target.receive_ingredient(held_ingredient)
		
		if received:
			print("🚚 Agent: a livré " + obj)
			hand_point.remove_child(held_ingredient)

			_update_label("Livre " + obj)
			update_anim("idle")
			await get_tree().create_timer(action_delay).timeout
			_update_label("Servi " + obj)
			await get_tree().create_timer(action_delay).timeout

			held_ingredient = null
			# release delivery zone reservation if any
			if target and target.has_method("release"):
				target.release(agent_id)
				# Clear held_reservation after successful delivery
				if held_reservation == target:
					held_reservation = null

	# ✅ Action terminée — clear state et passer à la suivante
	current_action_entry = null
	target = null
	action = ""
	
	# Small delay before next action
	await get_tree().create_timer(0.1).timeout
	_process_next_action()


# ---------------------------
# CONSTRUCTION D'UNE RECETTE
# ---------------------------

func make_recipe(recipe: Dictionary, table: String = "TableTravail1") -> void:
	# Stocker la recette en cours
	current_recipe = recipe
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

func cancel_action(action_id: int) -> bool:
	"""Cancel a specific action in the queue by its ID.
	Returns true if found and cancelled, false otherwise."""
	for i in range(action_queue.size()):
		if action_queue[i].get('id') == action_id:
			var cancelled = action_queue[i]
			action_queue.remove_at(i)
			print("🚫 Cancelled action:", cancelled.get('act'), cancelled.get('arg'), "(ID:", action_id, ")")
			emit_signal("action_cancelled", action_id, "user_request")
			return true
	
	# Check if it's the currently executing action
	if current_action_entry and current_action_entry.get('id') == action_id:
		print("🚫 Cancelling currently executing action (ID:", action_id, ")")
		_cancel_current_action(current_action_entry, "user_cancel")
		return true
	
	return false


func cancel_all_actions() -> void:
	"""Cancel all queued actions and reset agent state.
	Releases any held reservations."""
	var cancelled_count = action_queue.size()
	
	# Emit signal for each cancelled action
	for entry in action_queue:
		emit_signal("action_cancelled", entry.get('id'), "cancel_all")
	
	# Clear the queue
	action_queue.clear()
	
	# Cancel current action if any
	if is_busy and current_action_entry:
		_cancel_current_action(current_action_entry, "cancel_all")
		cancelled_count += 1
	else:
		# If not busy, still clean up any held reservations
		if held_reservation and held_reservation.has_method("release"):
			held_reservation.release(agent_id)
			held_reservation = null
		
		if target and target.has_method("release"):
			target.release(agent_id)
			target = null
	
	is_busy = false
	current_action_entry = null
	_update_label("Idle")
	
	print("🚫 Cancelled all actions. Total:", cancelled_count)


func get_action_queue_info() -> Array:
	"""Return info about queued actions for debugging/UI.
	Returns array of dicts with 'id', 'act', 'arg', 'attempts'."""
	var info = []
	for entry in action_queue:
		info.append({
			'id': entry.get('id', -1),
			'act': entry.get('act', ''),
			'arg': entry.get('arg', ''),
			'attempts': entry.get('attempts', 0)
		})
	return info


func _requeue_with_backoff_for(act_name: String, arg: String = "") -> void:
	# Uses exponential backoff and a per-action max retry limit.
	var attempts = 0
	if current_action_entry and current_action_entry.has("attempts"):
		attempts = int(current_action_entry.get("attempts")) + 1
	else:
		attempts = 1

	if attempts > retry_max_retries:
		print("⚠️ Agent: max retries (", retry_max_retries, ") reached for action:", act_name, arg)
		current_action_entry = null
		_update_label("Idle")
		return

	var delay = min(retry_initial_backoff * pow(retry_multiplier, attempts - 1), retry_max_backoff)
	print("⏱️ Requeueing action:", act_name, arg, "in", delay, "s (attempt", attempts, ")")
	await get_tree().create_timer(delay).timeout
	var entry = {'act': act_name, 'arg': arg, 'attempts': attempts}
	queue_actions([entry])


func _start_action_timeout_monitor(entry) -> void:
	# Detached monitor: waits action_timeout seconds and cancels the action if it is still the current one.
	var t = get_tree().create_timer(action_timeout)
	await t.timeout
	# If the same entry is still current and agent is busy, cancel it
	if current_action_entry == entry and is_busy:
		print("⏳ Action timeout: cancelling action", entry)
		_cancel_current_action(entry, "timeout")


func _cancel_current_action(entry, reason: String = "") -> void:
	print("❌ Cancel current action:", entry, "reason:", reason)
	# Restore current_action_entry so _requeue_with_backoff_for can compute the next attempt count
	current_action_entry = entry

	# Release reservation on the target if supported
	if target and target.has_method("release"):
		# best-effort: release using our agent_id
		target.release(agent_id)
	
	# Also release held_reservation if present (might differ from target in some cases)
	if held_reservation and held_reservation.has_method("release"):
		if held_reservation != target:  # avoid double-release
			held_reservation.release(agent_id)
		held_reservation = null

	# Clear local state
	target = null
	is_busy = false
	_update_label("Idle")

	# Requeue the action with backoff (this will increment attempts)
	_requeue_with_backoff_for(entry.get('act', ''), entry.get('arg', ''))


func _calculate_agent_avoidance() -> Vector2:
	"""Calcule une force de répulsion pour éviter les autres agents proches"""
	var avoidance = Vector2.ZERO
	
	if not agent_manager or not agent_manager.has_method("get_registered_agents"):
		return avoidance
	
	var all_agents = agent_manager.get_registered_agents()
	for other_agent in all_agents:
		if other_agent == self or other_agent == null:
			continue
		
		var distance_vec = global_position - other_agent.global_position
		var distance = distance_vec.length()
		
		# Si un autre agent est trop proche, appliquer une force de répulsion
		if distance < agent_avoidance_radius and distance > 0:
			var force_strength = (1.0 - distance / agent_avoidance_radius) * agent_avoidance_force
			avoidance += distance_vec.normalized() * force_strength
	
	return avoidance


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
	
func update_anim(force_anim: String = "") -> void:
	# Si une animation est forcée, on la joue directement
	if force_anim != "":
		anim.play(force_anim)
		return
	
	# Si l'animation est verrouillée, ne pas la changer
	if is_animation_locked:
		return
	
	# Sinon, logique basée sur le mouvement
	if velocity != Vector2.ZERO:
		anim.play("walk")
	else:
		anim.play("idle")
		
