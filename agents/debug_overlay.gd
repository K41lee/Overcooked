extends Control

# Debug Overlay pour visualiser toutes les réservations actives
# Toggle avec ESC

@export var enabled: bool = false
var agent_manager: Node = null

func _ready():
	# Remplir tout l'écran
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # Ne pas bloquer les inputs
	
	var scene = get_tree().current_scene
	if scene:
		agent_manager = scene.get_node_or_null("AgentManager")
	if not agent_manager:
		push_warning("DebugOverlay: AgentManager not found")

func _process(_delta):
	# Toggle avec ESC
	if Input.is_action_just_pressed("ui_cancel"):
		enabled = !enabled
		queue_redraw()
	
	if enabled:
		queue_redraw()

func _draw():
	if not enabled or not agent_manager:
		return
	
	var y_offset = 100
	
	# Afficher les stats watchdog
	if agent_manager.has_method("get_watchdog_stats"):
		var stats = agent_manager.get_watchdog_stats()
		draw_string(ThemeDB.fallback_font, Vector2(10, y_offset), "=== WATCHDOG STATS ===", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.CYAN)
		y_offset += 20
		draw_string(ThemeDB.fallback_font, Vector2(10, y_offset), "Scans: %d | Releases: %d | Rate: %.1f%%" % [stats.scans, stats.releases, stats.release_rate], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
		y_offset += 16
		draw_string(ThemeDB.fallback_font, Vector2(10, y_offset), "Active: %d | Agents: %d" % [stats.active_reservations, stats.registered_agents], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
		y_offset += 25
	
	# Scanner la scène pour toutes les ressources réservées
	var reservations = []
	var scene = get_tree().current_scene
	if scene:
		_scan_reservations(scene, reservations)
	
	# Afficher les réservations
	draw_string(ThemeDB.fallback_font, Vector2(10, y_offset), "=== RESERVATIONS ACTIVES (ESC pour toggle) ===", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.YELLOW)
	y_offset += 20
	
	if reservations.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(10, y_offset), "Aucune réservation active", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	else:
		for res in reservations:
			var age = Time.get_ticks_msec() / 1000.0 - res.reserved_at
			var text = "%s → Agent%d (%.1fs)" % [res.name, res.holder, age]
			var color = Color.GREEN if age < 5.0 else Color.ORANGE if age < 30.0 else Color.RED
			draw_string(ThemeDB.fallback_font, Vector2(10, y_offset), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
			y_offset += 18

func _scan_reservations(node: Node, results: Array) -> void:
	if "reserved_by" in node and node.reserved_by != -1:
		var info = {
			"name": node.name,
			"holder": node.reserved_by,
			"reserved_at": node.reserved_at if "reserved_at" in node else 0.0
		}
		results.append(info)
	
	for child in node.get_children():
		_scan_reservations(child, results)
