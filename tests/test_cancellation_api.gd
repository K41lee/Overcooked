# Test de l'API d'Annulation
# Test basique pour valider cancel_action et cancel_all_actions

extends Node

func _ready() -> void:
	print("=== Test API Annulation ===")
	
	# Load cuisinier scene
	var CuisinierScene = load("res://agent/cuisinier.tscn")
	var agent = CuisinierScene.instantiate()
	agent.agent_id = 99
	add_child(agent)
	
	# Connect to cancellation signal
	agent.action_cancelled.connect(_on_action_cancelled)
	
	var tests_passed = 0
	var tests_total = 0
	
	# Test 1: Queue multiple actions and get their info
	tests_total += 1
	agent.queue_actions([
		["pickup", "tomate"],
		["drop", "TableCoupe"],
		["pickup", "TableCoupe"]
	])
	
	var queue_info = agent.get_action_queue_info()
	if queue_info.size() == 3:
		print("✅ Test 1 PASSED: 3 actions queued")
		tests_passed += 1
	else:
		print("❌ Test 1 FAILED: Expected 3 actions, got", queue_info.size())
	
	# Test 2: Cancel specific action by ID
	tests_total += 1
	var first_id = queue_info[0]['id']
	var cancelled = agent.cancel_action(first_id)
	
	if cancelled and agent.action_queue.size() == 2:
		print("✅ Test 2 PASSED: Action cancelled by ID")
		tests_passed += 1
	else:
		print("❌ Test 2 FAILED: cancel_action didn't work correctly")
	
	# Test 3: Try to cancel non-existent action
	tests_total += 1
	var fake_cancel = agent.cancel_action(9999)
	if not fake_cancel:
		print("✅ Test 3 PASSED: Non-existent action returns false")
		tests_passed += 1
	else:
		print("❌ Test 3 FAILED: Should return false for non-existent ID")
	
	# Test 4: Cancel all actions
	tests_total += 1
	agent.cancel_all_actions()
	
	if agent.action_queue.size() == 0 and not agent.is_busy:
		print("✅ Test 4 PASSED: All actions cancelled")
		tests_passed += 1
	else:
		print("❌ Test 4 FAILED: cancel_all_actions didn't clear queue")
	
	# Test 5: Queue new actions after cancel_all
	tests_total += 1
	agent.queue_actions([["pickup", "oignon"]])
	if agent.action_queue.size() == 1:
		print("✅ Test 5 PASSED: Can queue after cancel_all")
		tests_passed += 1
	else:
		print("❌ Test 5 FAILED: Cannot queue after cancel_all")
	
	# Summary
	print("\n=== RÉSUMÉ ===")
	print("Tests passés:", tests_passed, "/", tests_total)
	
	if tests_passed == tests_total:
		print("✅ TOUS LES TESTS RÉUSSIS")
	else:
		print("❌ CERTAINS TESTS ONT ÉCHOUÉ")
	
	# Cleanup and quit
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()


func _on_action_cancelled(action_id: int, reason: String) -> void:
	print("📢 Signal reçu: action", action_id, "annulée (raison:", reason, ")")
