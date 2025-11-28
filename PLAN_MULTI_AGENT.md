# Plan d'Action Détaillé : Migration Multi-Agent Coopératif
## Projet Overcooked - Système de Cuisiniers Coopératifs

**Date**: 28 novembre 2025  
**État actuel**: Phase C.1 en cours - Infrastructure de base implémentée

---

## 📊 ÉTAT ACTUEL DU PROJET

### ✅ Phases Complétées

#### Phase A & A.1 - Infrastructure de Réservation (100%)
- ✅ API de réservation implémentée dans toutes les ressources
- ✅ Champs `reserved_by` et `reserved_at` présents
- ✅ Méthodes `reserve()`, `release()`, `is_reserved()` fonctionnelles
- ✅ Timestamps de réservation ajoutés (OS.get_ticks_msec)
- ✅ Propagation de `agent_id` dans toutes les interactions
- **Fichiers modifiés**: spawner.gd, pile_assiettes.gd, table_travail.gd, table_coupe.gd, fourneau.gd, zone_livraison.gd, ingredient.gd

#### Phase B & B.1 - AgentManager Central (100%)
- ✅ AgentManager créé et intégré à main.tscn
- ✅ Enregistrement/désenregistrement d'agents
- ✅ Sélection du plus proche + réservation atomique
- ✅ Système de groupes avec fallback runtime
- ✅ Groupes pattern-based (TableTravail1 → TableTravail)
- ✅ Candidats groupes priorisés (exact → base → générique)
- ✅ Détection et libération des réservations stales
- ✅ Watchdog actif (scan périodique des réservations orphelines)

#### Phase C - Refactorisation Agent (100%)
- ✅ Export `agent_id` dans cuisinier.gd
- ✅ Enregistrement auprès du manager
- ✅ Utilisation d'AgentManager pour pickup/drop/deliver
- ✅ Fallback direct si manager absent
- ✅ Libération correcte des réservations après usage

#### Phase C.1 - Retry/Backoff (75%)
- ✅ Backoff exponentiel configurable
- ✅ Max retries par action
- ✅ Action timeout avec annulation
- ✅ Requeue automatique avec délai progressif
- ⚠️ **EN COURS**: Reservation hold semantics (timestamps ajoutés aux ressources)
- ❌ **MANQUANT**: API d'annulation de queue
- ❌ **MANQUANT**: Tests automatisés

---

## 🎯 PLAN D'ACTION DÉTAILLÉ

### 🔴 PRIORITÉ 1 : Compléter Phase C.1 (3-5 heures)

#### Étape 1.1 : Reservation Hold Semantics ⚠️ EN COURS
**Objectif**: Garantir que la réservation est maintenue pendant le déplacement de l'agent

**Actions**:
1. ✅ Ajouter `reserved_at` dans toutes les ressources (FAIT)
2. ⬜ Modifier `cuisinier.gd` pour ne pas relâcher la réservation avant d'arriver
   - Actuellement : réservation → déplacement → action → release
   - Souhaité : réservation maintenue durant tout le cycle
3. ⬜ Ajouter une vérification dans `_physics_process` :
   ```gdscript
   # Dans _start_action, marquer explicitement la réservation comme "en cours d'utilisation"
   # Ne libérer qu'après _perform_action complètement terminé
   ```
4. ⬜ Tester avec 2 agents concurrents sur même ressource

**Fichiers à modifier**:
- `agent/cuisinier.gd` : ajuster logique de libération
- Tests manuels requis

**Temps estimé**: 1h

---

#### Étape 1.2 : API d'Annulation de Queue
**Objectif**: Permettre l'annulation d'actions en queue (pour éviter deadlocks)

**Actions**:
1. ⬜ Ajouter méthode `cancel_action(action_id)` dans cuisinier.gd
2. ⬜ Ajouter méthode `cancel_all_actions()` pour reset complet
3. ⬜ Identifier les actions par ID unique (ajout d'un champ `id` dans dict d'action)
4. ⬜ Lors d'une annulation, libérer toutes réservations associées
5. ⬜ Émettre signal `action_cancelled` pour debug

**Implémentation**:
```gdscript
# Dans cuisinier.gd
var next_action_id: int = 0
signal action_cancelled(action_id, reason)

func queue_actions(actions: Array) -> void:
    for act in actions:
        var entry = {}
        if typeof(act) == TYPE_DICTIONARY:
            entry = act
        else:
            entry = {'act': act[0], 'arg': act[1] if act.size() > 1 else "", 'attempts': 0}
        entry['id'] = next_action_id
        next_action_id += 1
        action_queue.append(entry)
    if not is_busy:
        _process_next_action()

func cancel_action(action_id: int) -> bool:
    for i in range(action_queue.size()):
        if action_queue[i].get('id') == action_id:
            var cancelled = action_queue[i]
            action_queue.remove_at(i)
            emit_signal("action_cancelled", action_id, "user_request")
            return true
    return false

func cancel_all_actions() -> void:
    for entry in action_queue:
        emit_signal("action_cancelled", entry.get('id'), "cancel_all")
    action_queue.clear()
    if target and target.has_method("release"):
        target.release(agent_id)
    target = null
    is_busy = false
    current_action_entry = null
    _update_label("Idle")
```

**Temps estimé**: 1h30

---

#### Étape 1.3 : Tests Automatisés Phase C.1
**Objectif**: Validation automatique des retry/backoff/timeout

**Actions**:
1. ⬜ Créer `tests/test_retry_backoff.gd`
   - Test backoff exponentiel (vérifier délais)
   - Test max retries (vérifier abandon après N tentatives)
   - Test timeout action (vérifier annulation après 30s)
2. ⬜ Créer `tests/test_concurrent_agents.gd`
   - 2 agents tentent même ressource
   - Vérifier que seul 1 réserve
   - Vérifier que le 2ème obtient backoff
3. ⬜ Créer `tests/test_hold_semantics.gd`
   - Agent réserve, se déplace, utilise, libère
   - Vérifier qu'aucun autre agent ne vole pendant déplacement

**Fichiers à créer**:
- `tests/test_retry_backoff.gd`
- `tests/test_concurrent_agents.gd`
- `tests/test_hold_semantics.gd`

**Temps estimé**: 2h

---

### 🟠 PRIORITÉ 2 : Multi-Agent Instanciation (2-3 heures)

#### Étape 2.1 : Créer Plusieurs Instances d'Agents
**Objectif**: Passer de 1 à N cuisiniers dans la scène

**Actions**:
1. ⬜ Modifier `main.gd` pour instancier plusieurs agents
   ```gdscript
   # main.gd
   @export var num_agents: int = 2
   var agents: Array = []
   
   func _ready():
       for i in range(num_agents):
           var agent = preload("res://agent/cuisinier.tscn").instantiate()
           agent.agent_id = i
           agent.position = Vector2(100 + i * 50, 100)
           add_child(agent)
           agents.append(agent)
       
       _start_new_recipe()
   ```

2. ⬜ Modifier `_start_new_recipe()` pour distribuer travail
   ```gdscript
   func _start_new_recipe():
       recipes.set_random_recipe()
       var rec = recipes.get_current_recipe()
       recipe_label.text = "Recette : " + rec["name"]
       
       # Assigner la recette à un agent disponible
       var available_agent = _find_available_agent()
       if available_agent:
           available_agent.make_recipe(rec, "TableTravail" + str(available_agent.agent_id + 1))
   
   func _find_available_agent() -> Node:
       for agent in agents:
           if not agent.is_busy:
               return agent
       return agents[0]  # fallback
   ```

3. ⬜ Ajouter plusieurs TableTravail dans la scène
   - TableTravail1, TableTravail2, TableTravail3...
   - Une par agent prévu

**Fichiers à modifier**:
- `main.gd`
- `main.tscn` (ajouter tables)

**Temps estimé**: 1h30

---

#### Étape 2.2 : Gestion de Files de Recettes Partagées
**Objectif**: Pool de recettes où agents piochent

**Actions**:
1. ⬜ Créer classe `RecipeQueue` dans `main.gd`
   ```gdscript
   class RecipeQueue:
       var pending_recipes: Array = []
       var completed_count: int = 0
       
       func add_recipe(recipe: Dictionary) -> void:
           pending_recipes.append(recipe)
       
       func get_next_recipe() -> Dictionary:
           if pending_recipes.size() > 0:
               return pending_recipes.pop_front()
           return {}
       
       func mark_completed(recipe: Dictionary) -> void:
           completed_count += 1
   ```

2. ⬜ Agents signalent quand ils finissent une recette
   ```gdscript
   # Dans cuisinier.gd, après deliver
   signal recipe_completed(agent_id)
   
   # Dans _perform_action, après deliver success
   emit_signal("recipe_completed", agent_id)
   ```

3. ⬜ Main écoute et assigne nouvelle recette
   ```gdscript
   # Dans main.gd _ready
   for agent in agents:
       agent.recipe_completed.connect(_on_agent_recipe_completed)
   
   func _on_agent_recipe_completed(aid: int):
       var next_recipe = recipe_queue.get_next_recipe()
       if next_recipe.is_empty():
           recipes.set_random_recipe()
           next_recipe = recipes.get_current_recipe()
       
       var agent = agents[aid]
       agent.make_recipe(next_recipe, "TableTravail" + str(aid + 1))
   ```

**Temps estimé**: 1h

---

### 🟡 PRIORITÉ 3 : Phase D - Debug Overlay (2 heures)

#### Étape 3.1 : HUD Par Agent
**Objectif**: Visualiser état de chaque agent en temps réel

**Actions**:
1. ⬜ Ajouter `AgentHUD` attaché à chaque cuisinier
   ```gdscript
   # agent/agent_hud.gd
   extends CanvasLayer
   
   @onready var status_label: Label = $Panel/StatusLabel
   @onready var queue_label: Label = $Panel/QueueLabel
   @onready var target_label: Label = $Panel/TargetLabel
   
   var agent: Node = null
   
   func _ready():
       agent = get_parent()
   
   func _process(_delta):
       if agent:
           status_label.text = "Agent %d: %s" % [agent.agent_id, "Busy" if agent.is_busy else "Idle"]
           queue_label.text = "Queue: %d actions" % agent.action_queue.size()
           target_label.text = "Target: %s" % (agent.target.name if agent.target else "None")
   ```

2. ⬜ Créer scène `agent/agent_hud.tscn` avec Panel + Labels
3. ⬜ Instancier HUD dans `cuisinier.tscn` (ou dans _ready)

**Temps estimé**: 1h

---

#### Étape 3.2 : Overlay Global des Réservations
**Objectif**: Visualiser toutes les réservations actives

**Actions**:
1. ⬜ Implémenter `agents/debug_overlay.gd` (actuellement vide)
   ```gdscript
   extends CanvasLayer
   
   @onready var reservations_label: Label = $Panel/ReservationsLabel
   var agent_manager: Node = null
   
   func _ready():
       agent_manager = get_node_or_null("/root/Main/AgentManager")
   
   func _process(_delta):
       if agent_manager:
           var text = "=== RÉSERVATIONS ===\n"
           var scene = get_tree().current_scene
           _scan_reservations(scene, text)
           reservations_label.text = text
   
   func _scan_reservations(node: Node, text: String) -> String:
       if "reserved_by" in node:
           if node.reserved_by != -1:
               var age = (OS.get_ticks_msec() / 1000.0) - node.reserved_at if node.reserved_at > 0 else 0
               text += "%s → Agent %d (%.1fs)\n" % [node.name, node.reserved_by, age]
       
       for child in node.get_children():
           text = _scan_reservations(child, text)
       
       return text
   ```

2. ⬜ Créer UI avec Panel flottant en haut à droite
3. ⬜ Toggle debug overlay avec touche (ex: F3)

**Temps estimé**: 1h

---

### 🟢 PRIORITÉ 4 : Phase E - Watchdog Amélioré (1 heure)

#### Étape 4.1 : Timeout Basé sur l'Âge
**Objectif**: Libérer réservations > X secondes automatiquement

**Actions**:
1. ⬜ Utiliser `reserved_at` dans watchdog
   ```gdscript
   # Dans agent_manager.gd _scan_node_for_stale
   if "reserved_by" in child and "reserved_at" in child:
       var holder = child.reserved_by
       if holder != -1:
           var age = (OS.get_ticks_msec() / 1000.0) - child.reserved_at
           
           # Libérer si holder non enregistré OU age > timeout
           if not (holder in agents) or age > reserve_timeout_seconds:
               if child.has_method('release'):
                   print("Watchdog: releasing stale/old reservation on", child.name, "holder=", holder, "age=", age)
                   child.release(holder)
   ```

2. ⬜ Exposer `reserve_timeout_seconds` comme @export (déjà fait, utiliser)

**Temps estimé**: 30min

---

#### Étape 4.2 : Métriques Watchdog
**Objectif**: Logger activité du watchdog pour debug

**Actions**:
1. ⬜ Ajouter compteurs dans AgentManager
   ```gdscript
   var watchdog_stats := {
       "scans": 0,
       "releases_stale_holder": 0,
       "releases_timeout": 0
   }
   ```

2. ⬜ Logger dans console périodiquement
   ```gdscript
   func _watchdog_loop():
       while watchdog_enabled:
           watchdog_stats["scans"] += 1
           _scan_and_release_stale()
           
           if watchdog_stats["scans"] % 10 == 0:
               print("Watchdog Stats:", watchdog_stats)
           
           await get_tree().create_timer(watchdog_interval).timeout
   ```

**Temps estimé**: 30min

---

### 🔵 PRIORITÉ 5 : Phase F - Tests Multi-Agent (3 heures)

#### Étape 5.1 : Scènes de Test Dédiées
**Objectif**: Scènes isolées pour tester comportements spécifiques

**Actions**:
1. ⬜ Créer `tests/scenes/test_two_agents_one_spawner.tscn`
   - 2 agents, 1 spawner
   - Les deux tentent pickup simultané
   - Valider qu'un seul réussit
   
2. ⬜ Créer `tests/scenes/test_recipe_handoff.tscn`
   - Agent1 prépare ingrédients
   - Agent2 assemble assiette
   - Valider coordination via TableTravail partagée
   
3. ⬜ Créer `tests/scenes/test_stale_detection.tscn`
   - Agent réserve puis crash (remove du scene tree)
   - Watchdog doit libérer automatiquement
   - Autre agent doit pouvoir réserver après

**Temps estimé**: 2h

---

#### Étape 5.2 : Scripts de Test Automatisés
**Objectif**: Tests non-interactifs exécutables via CLI

**Actions**:
1. ⬜ Créer `tests/run_all_tests.gd`
   ```gdscript
   extends SceneTree
   
   func _init():
       var tests = [
           "res://tests/test_reservation.gd",
           "res://tests/test_agent_manager.gd",
           "res://tests/test_retry_backoff.gd",
           "res://tests/test_concurrent_agents.gd"
       ]
       
       var all_passed = true
       for test_path in tests:
           print("\n=== Running:", test_path, "===")
           var test = load(test_path).new()
           if test.has_method("_run"):
               test._run()
           # Analyser stdout pour détecter FAIL/PASS
       
       if all_passed:
           print("\n✅ ALL TESTS PASSED")
           quit(0)
       else:
           print("\n❌ SOME TESTS FAILED")
           quit(1)
   ```

2. ⬜ Ajouter dans README.md commande de test
   ```bash
   godot --headless -s tests/run_all_tests.gd
   ```

**Temps estimé**: 1h

---

### 🟣 PRIORITÉ 6 : Phase G - Documentation & Packaging (2 heures)

#### Étape 6.1 : Documentation Migration
**Objectif**: Documenter changements et patterns utilisés

**Actions**:
1. ⬜ Créer `docs/MultiAgentMigration.md`
   - Architecture avant/après
   - Diagrammes de flux (pickup, drop, deliver)
   - API de réservation (référence complète)
   - Patterns de coordination (nearest-first, backoff, watchdog)
   
2. ⬜ Ajouter docstrings dans code clé
   - AgentManager.get_nearest_free_and_reserve
   - cuisinier._requeue_with_backoff_for
   - cuisinier._start_action_timeout_monitor

**Temps estimé**: 1h30

---

#### Étape 6.2 : README Mise à Jour
**Objectif**: Guide d'utilisation et configuration

**Actions**:
1. ⬜ Ajouter section "Multi-Agent Configuration"
   ```markdown
   ## Configuration Multi-Agent
   
   ### Ajout d'Agents
   1. Ouvrir `main.tscn`
   2. Instancier `agent/cuisinier.tscn`
   3. Définir `agent_id` unique (0, 1, 2...)
   4. Positionner dans la cuisine
   
   ### Paramètres de Retry/Backoff
   - `retry_initial_backoff`: Délai initial (0.5s)
   - `retry_multiplier`: Facteur exponentiel (2.0)
   - `retry_max_backoff`: Plafond (4.0s)
   - `retry_max_retries`: Tentatives max (5)
   - `action_timeout`: Timeout action (30s)
   ```

2. ⬜ Ajouter diagramme d'architecture
3. ⬜ Section "Troubleshooting" (deadlocks, réservations stuck...)

**Temps estimé**: 30min

---

## 📅 PLANNING RECOMMANDÉ

### Semaine 1 (Sprint 1) - Fondations Multi-Agent
**Objectif**: Système multi-agent fonctionnel de base

- Jour 1-2: Compléter Phase C.1 (hold semantics + API annulation)
- Jour 3: Tests Phase C.1
- Jour 4-5: Multi-agent instanciation (2-3 agents)
- **Livrable**: 2-3 agents pouvant travailler en parallèle sans conflit

### Semaine 2 (Sprint 2) - Debug & Robustesse
**Objectif**: Système observable et auto-réparable

- Jour 1: Debug Overlay (HUD + réservations)
- Jour 2: Watchdog amélioré (timeouts + métriques)
- Jour 3-4: Tests automatisés multi-agent
- Jour 5: Correction bugs détectés
- **Livrable**: Système stable avec diagnostics complets

### Semaine 3 (Sprint 3) - Documentation & Polish
**Objectif**: Projet prêt pour démo/review

- Jour 1-2: Documentation complète
- Jour 3: Scénarios de coordination avancés
- Jour 4: Optimisations performances
- Jour 5: Démo préparation
- **Livrable**: Projet multi-agent coopératif complet et documenté

---

## 🚀 OPTIMISATIONS FUTURES (Post-MVP)

### Coordination Avancée
1. **Task Assignment Intelligent**
   - Heuristique pour assigner recettes selon charge agents
   - Éviter qu'un agent monopolise les ressources rares
   
2. **Recipe Decomposition**
   - Découper recettes complexes en sous-tâches
   - Paralléliser préparation ingrédients
   
3. **Resource Prediction**
   - Anticiper conflits de réservation
   - Pré-réserver ressources pour prochaine action

### Performance
1. **Spatial Partitioning**
   - Diviser cuisine en zones
   - Agents préfèrent ressources dans leur zone
   
2. **Batch Reservation**
   - Réserver séquence de ressources en une fois
   - Éviter réservations partielles (deadlock)

### IA Comportementale
1. **Learning Patterns**
   - Logger performance recettes
   - Adapter stratégie selon historique
   
2. **Communication Inter-Agent**
   - Signaux "j'ai besoin de X"
   - Coordination explicite pour recettes complexes

---

## 🎯 CRITÈRES DE SUCCÈS

### Minimum Viable Product (MVP)
- ✅ 2-3 agents simultanés sans deadlock
- ✅ Réservations atomiques sur toutes ressources
- ✅ Retry automatique avec backoff
- ✅ Watchdog fonctionnel (libération auto)
- ✅ Tests basiques passants

### Production Ready
- ⬜ 5+ agents stables simultanés
- ⬜ 0 deadlocks pendant 10 recettes consécutives
- ⬜ Debug overlay temps réel
- ⬜ Documentation complète
- ⬜ Suite de tests automatisés (>80% couverture)

### Excellence
- ⬜ 10+ agents avec coordination optimale
- ⬜ Métriques temps réel (throughput recettes/min)
- ⬜ AI adaptive (apprentissage patterns)
- ⬜ Visualisation 3D des flux de travail
- ⬜ Zero-downtime agent add/remove

---

## 📝 NOTES IMPORTANTES

### Points d'Attention
1. **Deadlocks Potentiels**
   - Deux agents se bloquent mutuellement
   - Solution: timeout + release forcé via watchdog
   
2. **Race Conditions**
   - get_nearest + reserve non atomiques
   - ✅ Résolu via get_nearest_free_and_reserve atomique
   
3. **Réservations Fantômes**
   - Agent crash sans release
   - ✅ Watchdog détecte et nettoie

### Décisions Architecturales Clés
- **Centralisé vs Distribué**: AgentManager central choisi pour simplicité
- **Pull vs Push**: Agents "pull" recettes du pool (évite surcharge)
- **Pessimistic Locking**: Réservation avant déplacement (évite conflits)

---

## 📚 RÉFÉRENCES

### Fichiers Clés
- `agent/cuisinier.gd`: Logique agent individuel
- `agents/agent_manager.gd`: Coordination centrale
- `furniture/*/reserve()`: API réservation ressources
- `furniture/food/recipes.gd`: Définition recettes

### Patterns Utilisés
- **Resource Reservation Pattern**: Lock avant usage
- **Exponential Backoff**: Retry avec délai croissant
- **Watchdog Pattern**: Nettoyage automatique états invalides
- **Nearest-First Selection**: Optimisation spatiale

### Technologies
- **Godot 4.5**: Moteur de jeu
- **GDScript**: Langage scripting
- **Scene Tree**: Gestion hiérarchie objets
- **Signals**: Communication événementielle

---

**Dernière mise à jour**: 28 novembre 2025  
**Statut global**: 65% complété  
**Prochaine étape**: Compléter hold semantics (Étape 1.1)
