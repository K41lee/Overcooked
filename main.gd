extends Node2D

# Préchargement de la scène de cuisinier pour instanciation multiple
@onready var cuisinier_scene = preload("res://agent/cuisinier.tscn")
@onready var recipes = preload("res://furniture/food/recipes.gd").new()
@onready var recipe_label: Label = $UI/RecipeLabel
@onready var score_label: Label = $UI/ScoreLabel

var score: int = 0
var agents: Array = []  # Liste de tous les agents actifs
var work_tables: Array = ["TableTravail1", "TableTravail2", "TableTravail3"]
var recipe_queue: Array = []  # File d'attente de recettes à préparer

func _ready():
	# Supprimer le cuisinier existant dans la scène (sera recréé programmatiquement)
	if has_node("Cuisinier"):
		$Cuisinier.queue_free()
	
	# Activer le debug overlay (si présent dans la scène)
	if has_node("DebugOverlay/Control"):
		$DebugOverlay/Control.enabled = false  # Désactivé par défaut, toggle avec ESC
	
	# Instancier 3 agents avec agent_id uniques
	_spawn_agents(3)
	
	# Remplir la queue avec plusieurs recettes
	_initialize_recipe_queue(6)
	
	# Distribuer les premières recettes aux agents
	_distribute_recipes()


func _spawn_agents(count: int):
	"""Instancie N agents avec positions et IDs uniques"""
	var agent_hud_scene = preload("res://agents/agent_hud.tscn")
	var spawn_positions = [
		Vector2(186, 376),
		Vector2(250, 376),
		Vector2(314, 376)
	]
	
	for i in range(count):
		var agent = cuisinier_scene.instantiate()
		agent.agent_id = i  # ID unique pour les réservations
		agent.position = spawn_positions[i] if i < spawn_positions.size() else Vector2(186 + i * 64, 376)
		agent.name = "Agent" + str(i)
		add_child(agent)
		agents.append(agent)
		
		# Ajouter un HUD pour cet agent
		var hud = agent_hud_scene.instantiate()
		agent.add_child(hud)
		hud.set_agent(agent)
		
		# Connecter le signal recipe_completed de chaque agent
		agent.connect("recipe_completed", _on_agent_recipe_completed.bind(agent))
		
		print("🍳 Agent%d instancié à %v" % [i, agent.position])


func _initialize_recipe_queue(count: int):
	"""Génère une queue de recettes aléatoires"""
	for i in range(count):
		recipes.set_random_recipe()
		var rec = recipes.get_current_recipe()
		recipe_queue.append(rec)
		print("📝 Recette ajoutée à la queue: %s" % rec["name"])


func _distribute_recipes():
	"""Assigne une recette à chaque agent disponible"""
	for i in range(min(agents.size(), recipe_queue.size())):
		if recipe_queue.is_empty():
			break
		var agent = agents[i]
		var rec = recipe_queue.pop_front()
		var table = work_tables[i % work_tables.size()]  # Distribution round-robin des tables
		
		print("🎯 Assignment: Agent%d → %s sur %s" % [agent.agent_id, rec["name"], table])
		agent.make_recipe(rec, table)
	
	_update_ui()


func _on_agent_recipe_completed(agent):
	"""Callback quand un agent termine sa recette"""
	print("✅ Agent%d a terminé sa recette!" % agent.agent_id)
	add_score(10)
	
	# Assigner la prochaine recette disponible
	if not recipe_queue.is_empty():
		var rec = recipe_queue.pop_front()
		var table = work_tables[agent.agent_id % work_tables.size()]
		print("🎯 New Assignment: Agent%d → %s sur %s" % [agent.agent_id, rec["name"], table])
		agent.make_recipe(rec, table)
	else:
		print("🏁 Agent%d idle (queue vide)" % agent.agent_id)
	
	_update_ui()


func _update_ui():
	"""Met à jour l'affichage avec le nombre de recettes restantes"""
	recipe_label.text = "Recettes restantes: %d" % recipe_queue.size()


func add_score(points: int):
	score += points
	score_label.text = "Score : %d" % score
