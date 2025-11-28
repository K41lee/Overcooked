extends Node

class_name AgentManager

# Simple AgentManager to register agents and find+reserve nearby resources.
# This is intentionally small and self-contained so it can be autoloaded later.

var agents := {} # id -> node

# Watchdog configuration
@export var watchdog_enabled: bool = true
@export var watchdog_interval: float = 3.0 # seconds between scans
@export var reserve_timeout_seconds: int = 60 # optional: nodes may expose reserved_at to enable age-based release
@export var stats_log_interval: float = 30.0 # Log stats every N seconds (0 = disabled)

# Watchdog metrics
var watchdog_scans: int = 0
var watchdog_releases: int = 0
var watchdog_active_reservations: int = 0
var last_stats_log_time: float = 0.0

func _ready() -> void:
	# start the watchdog loop if enabled
	if watchdog_enabled:
		_watchdog_loop()
	else:
		# no-op
		pass

	# Ensure scene nodes are in sensible groups so get_nodes_in_group works even if the
	# editor scene didn't set groups on the PackedScene instances. We add each node
	# to a group named after the node's name (e.g. a node named "ZoneLivraison" will
	# be added to the "ZoneLivraison" group). This is a safe fallback that makes
	# group-based lookups robust at runtime.
	_ensure_scene_groups()

func _watchdog_loop() -> void:
	# Run a periodic async loop that scans for stale reservations and releases them.
	# This is intentionally simple and non-blocking: it yields on a timer between scans.
	while watchdog_enabled:
		_scan_and_release_stale()
		
		# Log stats periodically
		if stats_log_interval > 0:
			var now = Time.get_ticks_msec() / 1000.0
			if now - last_stats_log_time >= stats_log_interval:
				_log_watchdog_stats()
				last_stats_log_time = now
		
		var t = get_tree().create_timer(watchdog_interval)
		await t.timeout

func register_agent(agent_node: Node) -> void:
	if agent_node == null:
		return
	agents[agent_node.agent_id] = agent_node

func unregister_agent(agent_node: Node) -> void:
	if agent_node == null:
		return
	if agent_node.agent_id in agents:
		agents.erase(agent_node.agent_id)

func find_agent_by_id(id: int) -> Node:
	return agents.get(id, null)

func get_registered_agents() -> Array:
	"""Retourne un tableau de tous les agents enregistrés"""
	return agents.values()

func get_nearest_free_and_reserve(group_name: String, position: Vector2, agent_id: int) -> Node:
	# Collect candidates in the group
	var tree = get_tree()
	if tree == null:
		push_warning("AgentManager.get_nearest_free_and_reserve: SceneTree is null")
		return null
	# Build a list of candidate group names to search.
	# Try exact name, then strip trailing digits (TableTravail1 -> TableTravail),
	# and also allow a generic 'Spawner' group when appropriate.
	var group_candidates := []
	group_candidates.append(group_name)
	# strip trailing digits
	var base = group_name
	# strip trailing digits (no is_digit in this GDScript version)
	while base.length() > 0:
		var last_char = base.substr(base.length() - 1, 1)
		if last_char >= "0" and last_char <= "9":
			base = base.substr(0, base.length() - 1)
		else:
			break
	if base != group_name and base != "":
		group_candidates.append(base)
	# If it's a specific spawner like SpawnerTomate, also add 'Spawner' as fallback
	if group_name.begins_with("Spawner") and not group_candidates.has("Spawner"):
		group_candidates.append("Spawner")

	# Category aliases: map logical groups to category groups used for recipes
	if group_name == "TableCoupe" and not group_candidates.has("ChopStations"):
		group_candidates.append("ChopStations")
	if group_name == "Fourneau" and not group_candidates.has("CookStations"):
		group_candidates.append("CookStations")

	print("AgentManager: get_nearest_free_and_reserve called for group='", group_name, "' (candidates=", group_candidates, "), agent=", agent_id)

	# Prefer nodes from the most specific candidate group available.
	# This ensures that requesting 'SpawnerViande' won't return a different spawner
	# found under the generic 'Spawner' group if specific ones exist.
	var nodes := []
	var chosen_group: String = ""
	for g in group_candidates:
		var gnodes = tree.get_nodes_in_group(g)
		if gnodes != null and gnodes.size() > 0:
			print("AgentManager: found ", gnodes.size(), " nodes in group '", g, "'")
			# use this group's nodes only
			for n in gnodes:
				nodes.append(n)
			chosen_group = g
			break

	if nodes == null or nodes.size() == 0:
	# no group members found — try to resolve a single node by name in the current scene
		var scene = tree.current_scene
		if scene:
			# first try exact path
			if scene.has_node(group_name):
				var single = scene.get_node(group_name)
				print("AgentManager: found node by exact path: ", single)
				# if resource supports reservation, try to reserve it for the agent
				if single.has_method('reserve'):
					var ok = single.reserve(agent_id)
					if ok:
						return single
				else:
					# Inspect holder; check age of reservation to determine if stale
					var holder = null
					if "reserved_by" in single:
						holder = single.reserved_by
						print("AgentManager: reserve failed on node found by exact path. node=", single.name, " reserved_by=", str(holder), " for agent=", agent_id)
						if holder != null:
							# Check age if timestamp available
							if "reserved_at" in single:
								var age = Time.get_ticks_msec() / 1000.0 - single.reserved_at
								if age > reserve_timeout_seconds:
									print("AgentManager: reservation aged %.1fs > %ds — releasing" % [age, reserve_timeout_seconds])
									if single.has_method('release'):
										single.release(holder)
									if single.reserve(agent_id):
										return single
								# Reservation fresh — cannot steal
							return null
				return single

			# fallback: recursive search by name (case-insensitive)
			var found = _find_node_by_name(scene, group_name)
			if found:
				print("AgentManager: found node by recursive search: ", found)
				if found.has_method('reserve'):
					var ok2 = found.reserve(agent_id)
					if ok2:
						return found
					else:
						var holder2 = null
						if "reserved_by" in found:
							holder2 = found.reserved_by
						print("AgentManager: reserve failed on node found by recursive search. node=", found.name, " reserved_by=", str(holder2), " for agent=", agent_id)
						if holder2 != null:
							if "reserved_at" in found:
								var age2 = Time.get_ticks_msec() / 1000.0 - found.reserved_at
								if age2 > reserve_timeout_seconds:
									print("AgentManager: holder %d reservation aged %.1fs > %ds — releasing and retrying" % [holder2, age2, reserve_timeout_seconds])
									if found.has_method('release'):
										found.release(holder2)
									if found.reserve(agent_id):
										return found
								else:
									return null
							return null
				return found
		print("AgentManager: no nodes in group '", group_name, "' and no matching node in scene")
		return null

	# Build list of (node,dist)
	var arr := []
	for n in nodes:
		if n == null:
			continue
		var dist = 0.0
		if n is Node2D:
			dist = position.distance_to(n.position)
		else:
			dist = 0.0
		arr.append({'node': n, 'dist': dist})

	# sort by distance (ascending) using a single Callable comparator
	arr.sort_custom(_sort_by_dist)

	# Try to reserve in order
	for it in arr:
		var cand = it['node']
		if cand.has_method('reserve'):
			var ok = false
			ok = cand.reserve(agent_id)
			if ok:
				return cand
			else:
				# If reserve failed, check age of reservation to determine if stale
				var h = null
				if "reserved_by" in cand:
					h = cand.reserved_by
					print("AgentManager: candidate reserve failed for ", cand.name, ", reserved_by=", str(h))
					if h != null:
						if "reserved_at" in cand:
							var age3 = Time.get_ticks_msec() / 1000.0 - cand.reserved_at
							if age3 > reserve_timeout_seconds:
								print("AgentManager: holder %d reservation on %s aged %.1fs > %ds — releasing and retrying" % [h, cand.name, age3, reserve_timeout_seconds])
								if cand.has_method('release'):
									cand.release(h)
								if cand.reserve(agent_id):
									return cand
							# Reservation still fresh — skip this candidate
						continue
		else:
			# If resource has no reserve, consider it available and return it
			return cand

	return null

func _sort_by_dist(a, b) -> int:
	var da = float(a['dist'])
	var db = float(b['dist'])
	if da < db:
		return -1
	elif da > db:
		return 1
	return 0


func _find_node_by_name(parent: Node, name: String) -> Node:
	# recursive case-insensitive search for a node with given name under parent
	var lname = name.to_lower()
	for child in parent.get_children():
		if typeof(child) == TYPE_OBJECT and child is Node:
			if child.name.to_lower() == lname:
				return child
			var sub = _find_node_by_name(child, name)
			if sub:
				return sub
	return null

func debug_log_reservations(group_name: String = "") -> void:
	if group_name == "":
		print("AgentManager: listing registered agents:")
		for id in agents.keys():
			print(" - ", id, " -> ", agents[id])
		return

	var tree = get_tree()
	if tree == null:
		push_warning("AgentManager.debug_log_reservations: SceneTree is null")
		return

	var nodes = tree.get_nodes_in_group(group_name)
	print("Reservations for group:", group_name)
	for n in nodes:
		if n == null:
			continue
		if n.has_method('is_reserved'):
			print(n.name, "is_reserved:", n.is_reserved())
		elif n.has_meta('reserved_by'):
			print(n.name, "reserved_by(meta)", n.get_meta('reserved_by'))
		else:
			print(n.name, "no reservation API")


func _ensure_scene_groups() -> void:
	var tree = get_tree()
	if tree == null:
		return
	var scene = tree.current_scene
	if scene == null:
		return

	_add_groups(scene)
	print("AgentManager: ensured scene groups for current_scene")


func _add_groups(node: Node) -> void:
	for child in node.get_children():
		if child == null:
			continue
		# Add the node to a group named after its node name if not already in it
		if not child.is_in_group(child.name):
			child.add_to_group(child.name)
		# Also add pattern-based groups for common prefixes so e.g. "TableTravail1" -> group "TableTravail"
		var name = child.name
		var patterns = ["TableTravail", "TableCoupe", "Spawner", "Fourneau", "ZoneLivraison", "PileAssiettes", "Table"]
		for p in patterns:
			if name.begins_with(p) and not child.is_in_group(p):
				child.add_to_group(p)

		# Recurse
		_add_groups(child)


func _scan_and_release_stale() -> void:
	# Scan the current scene for nodes that have a 'reserved_by' property or 'is_reserved' method
	# and release reservations held by unregistered agents or that exceed reserve_timeout_seconds.
	watchdog_scans += 1
	var tree = get_tree()
	if tree == null:
		return
	var scene = tree.current_scene
	if scene == null:
		return

	# Reset active reservations counter before scan
	watchdog_active_reservations = 0
	_scan_node_for_stale(scene)


func _scan_node_for_stale(parent: Node) -> void:
	for child in parent.get_children():
		if child == null:
			continue

		# check reserved_by property
		if "reserved_by" in child:
			var holder = child.reserved_by
			if holder != -1 and holder != null:
				# Phase E: Use reserved_at timestamp to determine staleness (age-based release)
				if "reserved_at" in child:
					var age = Time.get_ticks_msec() / 1000.0 - child.reserved_at
					if age > reserve_timeout_seconds:
						if child.has_method('release'):
							print("AgentManager.watchdog: releasing AGED reservation on %s held by %d (age=%.1fs)" % [child.name, holder, age])
							child.release(holder)
							watchdog_releases += 1
						else:
							print("AgentManager.watchdog: node %s has aged holder %d but no release() method" % [child.name, holder])
					else:
						# Reservation active et valide
						watchdog_active_reservations += 1
				else:
					# Fallback: no reserved_at, check registration (old behavior, but with warning)
					if not (holder in agents):
						if child.has_method('release'):
							print("AgentManager.watchdog: releasing reservation on %s held by unregistered %d (no timestamp available)" % [child.name, holder])
							child.release(holder)
							watchdog_releases += 1
					else:
						watchdog_active_reservations += 1


		# if node provides is_reserved() but not reserved_by property, try to inspect via methods
		elif child.has_method('is_reserved') and child.has_method('release'):
			# If reserved and we can't find holder, attempt to release if aged
			if child.is_reserved():
				# try to inspect reserved_by and reserved_at
				var holder2 = null
				if "reserved_by" in child:
					holder2 = child.reserved_by
				elif child.has_method('get_meta') and child.has_meta('reserved_by'):
					holder2 = child.get_meta('reserved_by')
				
				if holder2 != null:
					if "reserved_at" in child:
						var age2 = Time.get_ticks_msec() / 1000.0 - child.reserved_at
						if age2 > reserve_timeout_seconds:
							print("AgentManager.watchdog: releasing aged reserved node %s held by %d (age=%.1fs)" % [child.name, holder2, age2])
							child.release(holder2)
							watchdog_releases += 1
						else:
							watchdog_active_reservations += 1
					elif not (holder2 in agents):
						print("AgentManager.watchdog: releasing reserved node %s held by unregistered %d (no timestamp)" % [child.name, holder2])
						child.release(holder2)
						watchdog_releases += 1
					else:
						watchdog_active_reservations += 1

		# recurse
		_scan_node_for_stale(child)


func _log_watchdog_stats() -> void:
	"""Log watchdog statistics for monitoring and debugging."""
	print("============================================================")
	print("WATCHDOG STATS")
	print("  Total scans: %d" % watchdog_scans)
	print("  Total releases: %d" % watchdog_releases)
	print("  Active reservations: %d" % watchdog_active_reservations)
	print("  Registered agents: %d" % agents.size())
	if watchdog_scans > 0:
		var release_rate = (float(watchdog_releases) / float(watchdog_scans)) * 100.0
		print("  Release rate: %.2f%%" % release_rate)
	print("============================================================")


func get_watchdog_stats() -> Dictionary:
	"""Return watchdog metrics as dictionary for programmatic access."""
	return {
		"scans": watchdog_scans,
		"releases": watchdog_releases,
		"active_reservations": watchdog_active_reservations,
		"registered_agents": agents.size(),
		"release_rate": (float(watchdog_releases) / float(watchdog_scans)) if watchdog_scans > 0 else 0.0
	}
