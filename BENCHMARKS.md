# Benchmarks Multi-Agent - Overcooked

## 📊 Description

Ce dossier contient 3 scènes de benchmark pour comparer l'efficacité du système multi-agent avec différents nombres d'agents travaillant sur 3 recettes simultanées.

## 🎯 Objectif

Mesurer quantitativement l'amélioration de performance en augmentant le nombre d'agents coopérant sur les mêmes recettes.

## 📁 Fichiers de Benchmark

### 1. `benchmark_1_agent.tscn` / `benchmark_1_agent.gd`
- **Configuration**: 1 seul agent pour 3 recettes
- **Hypothèse**: L'agent doit traiter séquentiellement les 3 recettes
- **Goulot d'étranglement**: Un seul agent ne peut travailler que sur une recette à la fois

### 2. `benchmark_2_agents.tscn` / `benchmark_2_agents.gd`
- **Configuration**: 2 agents pour 3 recettes
- **Hypothèse**: Amélioration significative avec parallélisation partielle
- **Limitation**: La 3ème recette doit attendre qu'un agent se libère

### 3. `benchmark_3_agents.tscn` / `benchmark_3_agents.gd`
- **Configuration**: 3 agents pour 3 recettes (1:1 optimal)
- **Hypothèse**: Performance maximale avec un agent dédié par recette
- **Avantage**: Parallélisation complète, pas d'attente

## 🚀 Utilisation

### Méthode 1 : Via Godot Editor
1. Ouvrir Godot
2. Charger le projet Overcooked
3. Lancer chaque scène individuellement :
   - `benchmark_1_agent.tscn`
   - `benchmark_2_agents.tscn`
   - `benchmark_3_agents.tscn`
4. Attendre 3 minutes (180 secondes)
5. Noter les résultats affichés dans la console

Le script lance automatiquement les 3 benchmarks en séquence et affiche les résultats.

## 📈 Métriques Mesurées

Chaque benchmark mesure et affiche :

| Métrique | Description | Unité |
|----------|-------------|-------|
| **Recettes complétées** | Nombre total de recettes terminées avec succès | Nombre |
| **Recettes ratées** | Nombre de recettes livrées incorrectement | Nombre |
| **Score final** | Score cumulé (+100 par succès, -50 par échec) | Points |
| **Recettes par minute** | Vitesse de production moyenne | rec/min |
| **Temps écoulé** | Durée totale du benchmark | Secondes |

## 📊 Affichage en Temps Réel

Pendant le benchmark, l'interface affiche :

- **Haut gauche**: `Score: XXX`
- **Haut centre**: `Recettes actives: [liste des 3 recettes]`
- **Haut droite**: `Temps restant: MM:SS`
- **Ligne 2**: `Agents: N | Complétées: X | Ratées: Y | Vitesse: Z.Z/min`

## 🎮 HUD des Agents

Chaque agent affiche son statut en temps réel :
- **Status**: Action actuelle (pickup, drop, deliver, etc.)
- **Queue**: Nombre d'actions restantes dans la file
- **Target**: Nœud cible actuel
- **Held**: Ingrédient tenu en main

## 🔬 Résultats Attendus

### Hypothèses de Performance

| Configuration | Recettes/min (estimé) | Ratio vs 1 agent |
|---------------|------------------------|------------------|
| 1 agent | 2-3 | 1.0x (baseline) |
| 2 agents | 4-5 | ~1.8x |
| 3 agents | 6-8 | ~2.5-3.0x |

### Facteurs Limitants

1. **1 agent**: 
   - Doit se déplacer entre 3 tables
   - Temps mort entre recettes
   - Utilisation sous-optimale des ressources

2. **2 agents**:
   - Bonne parallélisation mais une recette reste en attente
   - Possible contention sur les ressources partagées
   - Amélioration ~80% vs 1 agent

3. **3 agents**:
   - Parallélisation optimale (1:1)
   - Chaque agent se concentre sur une recette
   - Amélioration ~250-300% vs 1 agent
   - Contention possible sur spawners/coupes/fourneaux (3 instances chacun)

## 🛠️ Système de Réservation

Les benchmarks utilisent le système complet de réservation multi-agent :
- **AgentManager**: Coordonne les réservations
- **Watchdog**: Libère les réservations âgées (>60s)
- **Hold semantics**: Réservation maintenue pendant déplacement
- **Retry/backoff**: Gestion des conflits avec backoff exponentiel

## 📝 Analyse Post-Benchmark

Après exécution, comparer :

1. **Efficacité absolue**: Nombre de recettes complétées
2. **Qualité**: Ratio succès/échecs
3. **Vitesse**: Recettes par minute
4. **ROI**: Score final (considère les pénalités)

### Calcul du ROI
```
ROI = (Score_N_agents - Score_1_agent) / N
```

## 🐛 Debug

Si les performances sont anormales :
- Activer le debug overlay (ESC)
- Vérifier les réservations actives
- Observer les métriques watchdog
- Consulter les logs de l'AgentManager

## 📌 Notes Importantes

- **Durée fixe**: 3 minutes (180s) pour tous les benchmarks
- **Seed aléatoire**: Les recettes sont générées aléatoirement (résultats variables)
- **Conditions identiques**: Même scène, mêmes ressources, seul le nombre d'agents change
- **Pas de player input**: Les agents travaillent automatiquement

## 🔄 Reproductibilité

Pour des résultats reproductibles :
1. Lancer les 3 benchmarks dans le même ordre
2. Noter les conditions système (charge CPU, etc.)
3. Répéter 3-5 fois et faire la moyenne
4. Comparer les recettes/min plutôt que le score absolu

## 📧 Auteur

Système de benchmark créé pour l'analyse quantitative du système multi-agent coopératif dans Overcooked.
