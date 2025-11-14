extends Node2D

var reserved_by: int = -1

func _ready():
    # nothing special
    pass

func reserve(agent_id: int) -> bool:
    if reserved_by == -1:
        reserved_by = agent_id
        return true
    return false

func release(agent_id: int) -> void:
    if reserved_by == agent_id:
        reserved_by = -1

func is_reserved() -> bool:
    return reserved_by != -1
