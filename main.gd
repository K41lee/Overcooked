extends Node2D

@onready var agent = $Cuisinier
@onready var recipes = preload("res://furniture/food/recipes.gd").new()
@onready var recipe_label: Label = $UI/RecipeLabel
@onready var score_label: Label = $UI/ScoreLabel

var score: int = 0

func _ready():
	_start_new_recipe()


func _start_new_recipe():
	recipes.set_random_recipe()
	var rec = recipes.get_current_recipe()
	recipe_label.text = "Recette : " + rec["name"]
	agent.make_recipe(rec, "TableTravail1")


func add_score(points: int):
	score += points
	score_label.text = "Score : %d" % score
