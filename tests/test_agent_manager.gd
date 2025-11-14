extends Node

func _ready() -> void:
    var AgentManager = preload("res://agents/agent_manager.gd")
    var manager = AgentManager.new()
    add_child(manager)

    var mock = preload("res://tests/mock_resource.gd")

    var r1 = mock.new()
    r1.name = "R1"
    add_child(r1)
    r1.position = Vector2(100, 0)
    r1.add_to_group("SpawnerTomate")

    var r2 = mock.new()
    r2.name = "R2"
    add_child(r2)
    r2.position = Vector2(10, 0)
    r2.add_to_group("SpawnerTomate")

    var r3 = mock.new()
    r3.name = "R3"
    add_child(r3)
    r3.position = Vector2(50, 0)
    r3.add_to_group("SpawnerTomate")

    # Agent 7 should get the nearest (R2)
    var n = manager.get_nearest_free_and_reserve("SpawnerTomate", Vector2(0,0), 7)
    if n == null:
        print("FAIL: No node reserved")
    elif n.name != "R2":
        print("FAIL: Expected R2 reserved, got ", n.name)
    else:
        print("PASS: Nearest reserved is R2")

    # Agent 8 should get next nearest (R3)
    var n2 = manager.get_nearest_free_and_reserve("SpawnerTomate", Vector2(0,0), 8)
    if n2 == null:
        print("FAIL: Second reservation returned null")
    elif n2.name != "R3":
        print("FAIL: Expected R3 for agent 8, got ", n2.name)
    else:
        print("PASS: Second reservation OK")

    # r1 should still be free
    if r1.reserve(9):
        print("PASS: r1 reserved by 9 OK")
    else:
        print("FAIL: r1 should be free but reserve failed")

    get_tree().quit()
