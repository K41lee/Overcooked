extends Node

class_name AgentManager

# Simple AgentManager to register agents and find+reserve nearby resources.
# This is intentionally small and self-contained so it can be autoloaded later.

var agents := {} # id -> node

func _ready():
    # no-op for now
    pass

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
    var nodes = get_tree().get_nodes_in_group(group_name)
    if nodes.size() == 0:
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

    # sort by distance (ascending)
    arr.sort_custom(func(a,b):
        return int(a['dist'] - b['dist'])
    )

    # Try to reserve in order
    for it in arr:
        var cand = it['node']
        if cand.has_method('reserve'):
            var ok = false
            ok = cand.reserve(agent_id)
            if ok:
                return cand
            else:
                continue
        else:
            # If resource has no reserve, consider it available and return it
            return cand

    return null

func debug_log_reservations(group_name: String = "") -> void:
    if group_name == "":
        print("AgentManager: listing registered agents:")
        for id in agents.keys():
            print(" - ", id, " -> ", agents[id])
        return

    var nodes = get_tree().get_nodes_in_group(group_name)
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
