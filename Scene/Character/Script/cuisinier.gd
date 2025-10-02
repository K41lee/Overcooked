extends CharacterBody2D


var linear_force = 5
var posCB: Vector2
var direction
var states = ["idle","cook","move"]

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	MoveToTarget("CuttingBoard")
		
func MoveToTarget(target : String) -> void:
	posCB =  get_parent().get_node(target).global_position
	direction = (posCB - global_position).normalized()
	if global_position != posCB:
		velocity = direction * 150.0
		move_and_slide()
