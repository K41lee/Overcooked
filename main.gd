extends Node2D

var score : int = 0
@onready var score_label = $UI/ScoreLabel
@onready var recipe_label = $UI/RecipeLabel

func add_score(points : int) -> void:
	score += points
	score_label.text = "Score : %d" % score

func set_recipe(text : String) -> void:
	recipe_label.text = "Recette : %s" % text
