extends CanvasLayer

# HUD pour afficher l'état d'un agent en temps réel
# Se place au-dessus de chaque agent pour debugging

@onready var panel: Panel = $Panel
@onready var status_label: Label = $Panel/VBox/StatusLabel
@onready var queue_label: Label = $Panel/VBox/QueueLabel
@onready var target_label: Label = $Panel/VBox/TargetLabel
@onready var held_label: Label = $Panel/VBox/HeldLabel

var agent: Node2D = null
@export var update_interval: float = 0.2  # Update every 200ms

func _ready():
	# Start update loop
	_update_loop()

func set_agent(agent_node: Node2D) -> void:
	agent = agent_node

func _update_loop() -> void:
	while true:
		if agent:
			_update_display()
		await get_tree().create_timer(update_interval).timeout

func _update_display() -> void:
	if not agent:
		return
	
	# Position panel above agent
	var viewport_size = get_viewport().get_visible_rect().size
	var agent_screen_pos = agent.get_global_transform_with_canvas().origin
	panel.position = agent_screen_pos - Vector2(60, 80)  # Offset above agent
	
	# Status
	var status = "Idle"
	if "is_busy" in agent and agent.is_busy:
		status = "Busy"
	if "action" in agent and agent.action != "":
		status = agent.action.capitalize()
	status_label.text = "Agent%d: %s" % [agent.agent_id if "agent_id" in agent else -1, status]
	
	# Queue info
	var queue_size = 0
	if "action_queue" in agent:
		queue_size = agent.action_queue.size()
	var next_action = "—"
	if queue_size > 0 and "action_queue" in agent:
		var first = agent.action_queue[0]
		next_action = "%s %s" % [first.get("act", "?"), first.get("arg", "")]
	queue_label.text = "Queue: %d | Next: %s" % [queue_size, next_action]
	
	# Target
	var target_name = "—"
	if "target" in agent and agent.target != null:
		target_name = agent.target.name
	target_label.text = "Target: %s" % target_name
	
	# Held item
	var held = "—"
	if "held_ingredient" in agent and agent.held_ingredient != null:
		if "type" in agent.held_ingredient:
			held = agent.held_ingredient.type
		else:
			held = "object"
	held_label.text = "Holding: %s" % held
