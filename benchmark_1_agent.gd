extends Node2D

# Benchmark avec 1 AGENT
# Compare l'efficacité d'avoir 1 seul agent pour 3 recettes

@onready var cuisinier_scene = preload("res://agent/cuisinier.tscn")
@onready var recipes = preload("res://furniture/food/recipes.gd").new()
@onready var recipe_label: Label = $UI/RecipeLabel
@onready var score_label: Label = $UI/ScoreLabel
@onready var timer_label: Label = $UI/TimerLabel
@onready var stats_label: Label = $UI/StatsLabel

var score: int = 0
var agents: Array = []
var work_tables: Array = ["TableTravail1", "TableTravail2", "TableTravail3"]
var active_recipes: Array = []
var max_active_recipes: int = 3

# Stats de benchmark
var elapsed_time: float = 0.0
var recipes_completed: int = 0
var recipes_failed: int = 0
var benchmark_duration: float = 180.0  # 3 minutes

func _ready():
	if has_node("Cuisinier"):
		$Cuisinier.queue_free()
	
	if has_node("DebugOverlay/Control"):
		$DebugOverlay/Control.enabled = false
	
	# 1 SEUL AGENT
	_spawn_agents(1)
	_fill_active_recipes()
	_distribute_recipes()
	_update_stats()

func _process(delta):
	elapsed_time += delta
	_update_timer()
	
	if elapsed_time >= benchmark_duration:
		_end_benchmark()

func _spawn_agents(count: int):
	var agent_hud_scene = preload("res://agents/agent_hud.tscn")
	var spawn_positions = [
		Vector2(186, 376),
		Vector2(250, 376),
		Vector2(314, 376)
	]
	
	for i in range(count):
		var agent = cuisinier_scene.instantiate()
		agent.agent_id = i
		agent.position = spawn_positions[i] if i < spawn_positions.size() else Vector2(186 + i * 64, 376)
		agent.name = "Agent" + str(i)
		add_child(agent)
		agents.append(agent)
		
		var hud = agent_hud_scene.instantiate()
		agent.add_child(hud)
		hud.set_agent(agent)
		agent.connect("recipe_completed", _on_agent_recipe_completed.bind(agent))
		
		print("🍳 Agent%d instancié à %v" % [i, agent.position])

func _fill_active_recipes():
	while active_recipes.size() < max_active_recipes:
		recipes.set_random_recipe()
		var rec = recipes.get_current_recipe().duplicate()
		active_recipes.append(rec)
		print("📝 Nouvelle recette active: %s" % rec["name"])
	_update_ui()

func _distribute_recipes():
	for i in range(min(agents.size(), active_recipes.size())):
		if active_recipes.is_empty():
			break
		var agent = agents[i]
		var rec = active_recipes[i]
		var table = work_tables[i % work_tables.size()]
		
		print("🎯 Assignment: Agent%d → %s sur %s" % [agent.agent_id, rec["name"], table])
		agent.make_recipe(rec, table)
	
	_update_ui()

func _on_agent_recipe_completed(agent):
	print("✅ Agent%d a terminé sa recette!" % agent.agent_id)
	recipes_completed += 1
	
	var agent_index = agents.find(agent)
	if agent_index != -1 and agent_index < active_recipes.size():
		recipes.set_random_recipe()
		var new_rec = recipes.get_current_recipe().duplicate()
		active_recipes[agent_index] = new_rec
		print("📝 Nouvelle recette générée: %s" % new_rec["name"])
		
		var table = work_tables[agent_index % work_tables.size()]
		print("🎯 New Assignment: Agent%d → %s sur %s" % [agent.agent_id, new_rec["name"], table])
		agent.make_recipe(new_rec, table)
	
	_update_ui()
	_update_stats()

func _update_ui():
	var recipe_names = []
	for rec in active_recipes:
		recipe_names.append(rec["name"])
	recipe_label.text = "Recettes actives: " + ", ".join(recipe_names)

func _update_timer():
	var remaining = benchmark_duration - elapsed_time
	var minutes = int(remaining) / 60
	var seconds = int(remaining) % 60
	timer_label.text = "Temps restant: %02d:%02d" % [minutes, seconds]

func _update_stats():
	var recipes_per_min = (recipes_completed / elapsed_time) * 60.0 if elapsed_time > 0 else 0.0
	stats_label.text = "Agents: 1 | Complétées: %d | Ratées: %d | Vitesse: %.1f/min" % [recipes_completed, recipes_failed, recipes_per_min]

func _end_benchmark():
	set_process(false)
	print("\n============================================================")
	print("BENCHMARK TERMINÉ - 1 AGENT")
	print("============================================================")
	print("Durée: %.1fs" % elapsed_time)
	print("Recettes complétées: %d" % recipes_completed)
	print("Recettes ratées: %d" % recipes_failed)
	print("Score final: %d" % score)
	print("Recettes par minute: %.2f" % ((recipes_completed / elapsed_time) * 60.0))
	print("============================================================\n")

func add_score(points: int):
	score += points
	if points < 0:
		recipes_failed += 1
	score_label.text = "Score : %d" % score
	_update_stats()
