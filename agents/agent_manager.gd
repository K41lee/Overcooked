extends Node

class_name AgentManager

# Simple AgentManager to register agents and find+reserve nearby resources.
# This is intentionally small and self-contained so it can be autoloaded later.

var agents := {} # id -> node

# Watchdog configuration
@export var watchdog_enabled: bool = true
@export var watchdog_interval: float = 3.0 # seconds between scans
@export var reserve_timeout_seconds: int = 60 # optional: nodes may expose reserved_at to enable age-based release

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

func get_nearest_free_and_reserve(group_name: String, position: Vector2, agent_id: int) -> Node:
	# Collect candidates in the group
	var tree = get_tree()
	if tree == null:
		push_warning("AgentManager.get_nearest_free_and_reserve: SceneTree is null")
		return null
	var nodes = tree.get_nodes_in_group(group_name)
	print("AgentManager: get_nearest_free_and_reserve called for group='", group_name, "', agent=", agent_id)
	if nodes != null:
		print("AgentManager: found ", nodes.size(), " nodes in group '", group_name, "'")
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
						# Inspect holder; if holder agent is not registered, consider it stale and release
						var holder = null
						if "reserved_by" in single:
							holder = single.reserved_by
							print("AgentManager: reserve failed on node found by exact path. node=", single.name, " reserved_by=", str(holder), " for agent=", agent_id)
							if holder != null and holder in agents:
								# holder still active — cannot steal
								return null
							else:
								print("AgentManager: holder " , str(holder), " not registered — releasing stale reservation and retrying")
								if single.has_method('release') and holder != null:
									single.release(holder)
								# try to reserve again
								if single.reserve(agent_id):
									return single
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
						if holder2 != null and holder2 in agents:
							return null
						else:
							print("AgentManager: holder ", str(holder2), " not registered — releasing stale reservation and retrying")
							if found.has_method('release') and holder2 != null:
								found.release(holder2)
							if found.reserve(agent_id):
								return found
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
				# If reserve failed, check if the holder is still registered; if not, release and retry
				var h = null
				if "reserved_by" in cand:
					h = cand.reserved_by
					print("AgentManager: candidate reserve failed for ", cand.name, ", reserved_by=", str(h))
					if h != null and h in agents:
						continue
					else:
						print("AgentManager: releasing stale reservation held by ", str(h), " on ", cand.name)
						if cand.has_method('release') and h != null:
							cand.release(h)
						# try to reserve again
						if cand.reserve(agent_id):
							return cand
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
		# Recurse
		_add_groups(child)


func _scan_and_release_stale() -> void:
	# Scan the current scene for nodes that have a 'reserved_by' property or 'is_reserved' method
	# and release reservations held by unregistered agents or that exceed reserve_timeout_seconds.
	var tree = get_tree()
	if tree == null:
		return
	var scene = tree.current_scene
	if scene == null:
		return

	_scan_node_for_stale(scene)


func _scan_node_for_stale(parent: Node) -> void:
	for child in parent.get_children():
		if child == null:
			continue

		# check reserved_by property
		if "reserved_by" in child:
			var holder = child.reserved_by
			if holder != -1 and holder != null:
				# If holder not registered, release stale reservation
				if not (holder in agents):
					if child.has_method('release'):
						print("AgentManager.watchdog: releasing stale reservation on", child.name, "held by", str(holder))
						child.release(holder)
					else:
						print("AgentManager.watchdog: node", child.name, "has stale holder", str(holder), "but no release() method")


		# if node provides is_reserved() but not reserved_by property, try to inspect via methods
		elif child.has_method('is_reserved') and child.has_method('release'):
			# If reserved and we can't find holder, attempt to release if holder unregistered via debug method
			if child.is_reserved():
				# try to inspect reserved_by meta or property via get
				var holder2 = null
				if "reserved_by" in child:
					holder2 = child.reserved_by
				elif child.has_method('get_meta') and child.has_meta('reserved_by'):
					holder2 = child.get_meta('reserved_by')
				if holder2 != null and not (holder2 in agents):
					print("AgentManager.watchdog: releasing reserved node", child.name, "held by unregistered", str(holder2))
					child.release(holder2)

		# recurse
		_scan_node_for_stale(child)
