# Destination of Power

A top-down 2D roguelike adventure MVP set in **Nerax**, capital city of the world of **Hamia**, built in **Godot 4** with **GDScript**. Character creation, class selection, a skippable lore intro, top-down exploration, turn-based combat, equipment/inventory, an event-driven artifact system, and a randomized encounter run structure — all backed by data files so new content can be added without touching the code that renders it.

All visuals are procedural placeholder shapes (`Polygon2D`/`ColorRect`, solid colors) built from data. No external art or paid assets are used, and everything is designed to be swapped for real art later without changing any game logic.

## Requirements

- **Godot 4.3+** (developed/tested against 4.7). Any 4.x editor should open the project; the "Compatibility" (GL Compatibility) rendering method is used so it also runs on modest hardware.

## Running the project

1. Open Godot 4, choose **Import**, and select this folder's `project.godot`.
2. Press **F5** (Run Project) or the Play button. The game boots into `scenes/Main.tscn`, which immediately hands off to the Main Menu.
3. On first run there is no saved character, so **New Game** is disabled — start with **Character Creation**.

No external services, accounts, or network access are required.

## Controls

| Action | Key |
| --- | --- |
| Move | `WASD` or Arrow Keys |
| Interact | `E` |
| Pause / Character Info | `Esc` |
| Inventory | `I` |
| Advance / Skip dialogue text | `Space`, `Enter`, or mouse click |
| Menus | Mouse, or Tab/Arrows + Enter (all buttons are focusable) |

All bindings are defined in **Project Settings → Input Map** (`move_up/down/left/right`, `interact`, `pause_menu`, `inventory_toggle`, `ui_advance`), so remapping or adding a controller/mobile input layer later only means adding new events to those same actions - no script changes needed.

## Game flow

Main Menu → Character Creation → (return to menu) → New Game → Class Selection → Lore Intro → Back Alley (exploration) → randomized Encounters (combat / treasure / empty / event / healing) → Run Summary → Main Menu.

## Architecture overview

The project is split into **autoload singletons** (global systems), **data resources** (content, as `.tres` files), and **scenes** (screens/entities that consume that data). Nothing hardcodes game content into UI code - every screen that lists classes, items, artifacts, enemies, appearance options or encounter types reads its list from a registry at runtime.

### Autoloads (`scripts/autoload/`)

| Singleton | Responsibility |
| --- | --- |
| `EventBus` | Global signal bus for combat/run lifecycle events (`combat_started`, `player_attacked`, `enemy_defeated`, `item_used`, `health_low`, etc.) |
| `SaveManager` | Reads/writes the three JSON save files under `user://saves/` (profile, run, settings). Versioned (`save_version`) for future migration. |
| `SceneManager` | Centralizes scene transitions (with a fade) and the "pending combat" hand-off between exploration/encounter scenes and `CombatScene`. |
| `AbilityRegistry`, `ClassRegistry`, `ItemRegistry`, `ArtifactRegistry`, `EnemyRegistry`, `EncounterRegistry`, `AppearanceRegistry` | Each scans its `resources/...` folder at startup and loads every `.tres` file it finds into a lookup table. **Adding content = adding a file.** |
| `ArtifactSystem` | Keeps one persistent effect-object per held artifact and fans out `EventBus` combat events to each one's matching hook. |
| `RunManager` | Owns the current `CharacterProfile` and active `RunData`; computes effective stats (class base + equipment + artifacts). |
| `AudioManager` | Applies/persists volume + fullscreen settings. No audio assets ship with the MVP; hooks (`play_sfx`, `play_music`) are ready for them. |

### Data resources (`scripts/data/`, content in `resources/`)

Custom `Resource` subclasses, saved as `.tres` files: `CharacterProfile`, `RunData`, `SettingsData` (save data); `ClassDefinition`, `AbilityDefinition`, `ItemDefinition`, `ArtifactDefinition`, `EnemyDefinition`, `AppearanceOption`, `ColorSwatch`, `EncounterEntry`, `LoreScript`, `StatBlock` (game content). None of these reference scene nodes - they're pure data and can be edited in the Godot inspector or a text editor.

### Combat (`scripts/combat/`)

`CombatManager` (a plain `Node`, not tied to any UI) owns a `TurnQueue` (speed-sorted turn order) and two `CombatUnitState` instances (player + enemy runtime stats). It exposes `player_basic_attack()`, `player_use_ability()`, `player_use_item()`, `player_defend()`, `end_turn()` and reports back through signals (`log_message`, `stats_changed`, `turn_changed`, `combat_finished`). `CombatHUD` and `CombatScene` are purely presentational - they never touch combat rules directly.

`CombatScene.tscn`'s world content (`Background`, `Floor`, `PlayerAppearanceRoot`, `AllyContainer`, `EnemyContainer`) is laid out in world-space assuming a camera centered on the origin - it always needs its own `Camera2D` at `(0, 0)` for that to render correctly (it was missing for a while, which pushed every combatant token up into the top-left corner of the screen, on top of the HUD's health bar; headless boot tests can't catch this class of bug since they never actually render a frame - it took an on-screen screenshot to find and confirm the fix). If you retune the stage layout, a quick way to sanity-check it without a monitor is a throwaway script that adds an instanced `CombatScene` as a child, waits a few `_process` frames, and calls `get_viewport().get_texture().get_image().save_png(...)`.

### Artifacts (`scripts/artifacts/`)

`ArtifactEffectBase` defines one virtual hook per `EventBus` combat event. Each artifact's behaviour lives in its own subclass under `scripts/artifacts/effects/` (`CinderRingEffect`, `MoonstoneCharmEffect`, `ThornedCoinEffect`, `HuntersEyeEffect`, `BrokenCrownEffect`) - there is no single giant `match effect_id:` block executing gameplay logic. `ArtifactEffectFactory` maps an `ArtifactDefinition.effect_id` string to its class, and `ArtifactSystem` keeps the instances alive for the run so stateful effects (e.g. Cinder Ring's "primed" flag) work correctly across turns.

### Character appearance (`scripts/entities/CharacterAppearanceRenderer.gd`)

Given a `CharacterProfile`, this builds five layered children in a fixed order (body → lower clothing → upper clothing → footwear → hair) using each selected `AppearanceOption`'s placeholder polygon (or a `texture`, if one is assigned later) tinted by skin/hair color. The same renderer is used by the Character Creator preview, `PlayerCharacter` in exploration, and `CombatScene` - the appearance is always built from the same data, so it's automatically consistent everywhere.

### Scenes

```
scenes/Main.tscn                 - boot scene, hands off to MainMenu
scenes/ui/MainMenu.tscn
scenes/ui/SettingsMenu.tscn
scenes/ui/CharacterCreator.tscn
scenes/ui/ClassSelection.tscn
scenes/ui/LoreIntro.tscn
scenes/ui/ExplorationHUD.tscn    - instanced inside every exploration area
scenes/ui/PauseMenu.tscn         - instanced inside every exploration area
scenes/ui/InventoryScreen.tscn   - instanced inside every exploration area
scenes/ui/CombatHUD.tscn         - instanced inside CombatScene
scenes/ui/RunSummary.tscn
scenes/ui/DialogueChoicePopup.tscn - Yes/No/decline NPC prompt; instanced only where used (Plaza)
scenes/world/BackAlley.tscn      - starting exploration area (dead end, one way out)
scenes/world/TwoWayAlley.tscn    - junction alley: Back Alley <-> Plaza, has a trader
scenes/world/Plaza.tscn          - Nerax's central plaza: food vendor, swindler, adventurer NPC, guild hall door
scenes/world/AdventureCentrum.tscn  - guild hall; resolves the Find Wassim quest on arrival, loot sellers, receptionist, mission board
scenes/world/GuildLounge.tscn        - C-Rank+ only; member-discounted shop
scenes/world/CityGuardArrival.tscn  - story beat: guard arrives, revenge thugs incoming
scenes/world/CityGuardFarewell.tscn - story beat: guard asks where you live, assumes Southside
scenes/world/DeeperAlley.tscn        - the alley's other path; the Sticky-Fingered Thug ambushes here
scenes/world/UndergroundNerax.tscn  - minimal stub beneath the Deeper Alley, not built out yet
scenes/world/Market.tscn             - Southside's long market street, Plaza <-> the southern gate
scenes/world/NeraxOutskirts.tscn    - beyond the gate: forest (bees) east, lake west
scenes/world/FarReaches.tscn         - minimal stub south of the outskirts, not built out yet
scenes/world/MaskedManEncounter.tscn - one-time cinematic: a masked man taunts the player in the forest
scenes/world/DeepForest.tscn         - bigger forest beyond the portal: sleeping bear, hunter
scenes/world/EncounterScreen.tscn- hub for the randomized run sequence
scenes/combat/CombatScene.tscn
scenes/entities/PlayerCharacter.tscn
scenes/entities/EnemyCharacter.tscn
```

`scripts/world/ExplorationArea.gd` is the shared base class behind every walkable area (`BackAlley`, `TwoWayAlley`, `Plaza`) - it owns the player/HUD/pause/inventory wiring and all `Interactable` handling (message, combat, exit, heal, item, trade). A concrete area is typically a `.tscn` plus a script that's just `extends ExplorationArea` and overrides `get_scene_path()`/`get_objective_text()` (and optionally `_on_area_ready()` for one-time setup like an intro notification) - see `BackAlley.gd` for the smallest example.

## Save data

Three independent JSON files under `user://saves/` (on Windows: `%APPDATA%/Godot/app_userdata/Destination of Power/saves/`):

- `character_profile.json` - name + appearance. Survives runs and app restarts; only overwritten by **Save Character** in the creator.
- `active_run.json` - class, stats, inventory, equipped items, artifacts, currency, encounter progress, run seed. Deleted when a run ends (victory, defeat, or is explicitly abandoned).
- `settings.json` - volume levels and fullscreen toggle.

Each has a `save_version` integer field. `SaveManager`/`CharacterProfile`/`RunData`/`SettingsData` read missing or malformed files gracefully (missing file → `null`/defaults, not a crash) which is where a future migration step would branch on `save_version`.

## Adding content

Everything below is "add a file," not "edit a script."

### Add a hairstyle

1. Duplicate any file in `resources/appearance/hair/` (e.g. `hair_short.tres`).
2. Give it a unique `id`, a `display_name`, and a new `shape_points` polygon (local-space points around the head, same coordinate space as the other hairstyles - see `hair_long.tres` for reference). Set `uses_hair_color = true`.
3. Save it anywhere inside `resources/appearance/hair/`. It's picked up automatically the next time `AppearanceRegistry` scans the folder (on next run of the project) - no code changes.
4. To use real artwork instead of the placeholder polygon, assign a `Texture2D` to the option's `texture` field; the renderer prefers the texture automatically.

### Add clothing (shirt / pants / footwear)

Same process, in `resources/appearance/shirts/`, `resources/appearance/pants/`, or `resources/appearance/footwear/`. Set `tint_color` to the garment's placeholder color (clothing doesn't use the skin/hair palettes). Body types and color swatches (`resources/appearance/body/`, `skin_colors/`, `hair_colors/`) follow the same "duplicate, edit, drop in the folder" pattern.

### Core stats

Every character (class or enemy) is built from a `StatBlock` (`scripts/data/StatBlock.gd`) with five core stats - **HP, Attack, Defense, Speed, Intelligence** - plus a separate class resource pool (mana/stamina/energy, labeled per class via `resource_label`, not one of the five). Every class starts everyone at 5 in Attack/Defense/Speed/Intelligence and raises exactly **one** of the five by +5 (its `impact_stat`, shown on the Class Selection screen). HP is the exception: because "5 HP" isn't survivable, the HP stat is stored already multiplied by `StatBlock.HP_STAT_MULTIPLIER` (10) - so the shared baseline is 50 max health, and the HP-focused class's +5 becomes +50 (100 total). See the constant's doc comment in `StatBlock.gd` for the full convention. To add a sixth stat later, add a field to `StatBlock` and touch whatever combat/UI code should read it (search for `intelligence` in `scripts/` for every place a core stat currently gets read/displayed - a new stat needs the same treatment).

The class resource pool (mana/stamina/energy) is not stored directly - it's always derived at read time in `RunManager.compute_current_stats()` as `Intelligence * RunManager.MANA_PER_INTELLIGENCE` (10), plus any flat bonuses from equipped items/artifacts. Raising Intelligence (by class bonus, leveling, or gear) always raises the resource pool too.

### Combat damage formula

`CombatManager.damage_multiplier()` (a pure static function, easy to unit-test or retune) implements the attack-vs-defense comparison:

- Base damage comes from **Attack** for weapon attacks and non-magic abilities, or a blend of **50% Attack + 25% Intelligence** for abilities marked `uses_intelligence = true` ("spells"), multiplied by the ability's `power`.
- The attacker's raw **Attack** stat is then compared against the defender's *effective* Defense (`CombatUnitState.get_effective_defense()` = Defense × (1 + any active Defend/Guard bonus)): equal stats mean no change; every 1% the attacker's Attack exceeds the defender's Defense adds half a percent of bonus damage, and every 1% the defender's Defense exceeds the attacker's Attack cuts half a percent of damage - exactly mirroring each other. This is clamped to +300%/-90% as a safety bound (see the constants at the top of `CombatManager.gd`) so an extreme stat gap can't produce a runaway or negative result; a 1-damage floor still applies underneath that in `CombatUnitState.apply_damage()`.
- Critical hits (from artifacts like Hunter's Eye) apply their multiplier before the defense comparison; artifact flat bonuses (like Cinder Ring) are added to the base damage before that too - defense scales the whole finished hit, source included.

### Turn order & speed

Turns are not a simple alternating queue. At the start of each round, `CombatManager._begin_new_round()` finds the slowest living combatant (player included) and gives every combatant `floor(their_speed / slowest_speed)` actions for that round (minimum 1) - so double the slowest Speed means two actions per round, triple means three, and so on. Combatants then act in descending action-count order, each one using its whole block of actions consecutively before the next combatant's block starts (with a single enemy this reduces exactly to "faster side bursts, slower side gets one hit, repeat"). The ratio is recalculated fresh every round, which is what makes this ready for future speed buffs/debuffs "later," per the request that started this feature - a mid-combat effect just needs to change `speed` on the relevant `CombatUnitState` and the next round picks it up automatically. `CombatHUD` shows a "(2/4)" style counter during multi-action blocks (`CombatManager.get_current_block_progress()`).

### Targeting & allies

Combat supports any number of enemies and allies simultaneously (each gets its own speed-based turn slot in the round system above). `CombatHUD` shows a clickable target list (top-right) whenever enemies are alive - clicking a row calls `CombatManager.set_target()`, and `get_current_target()` is what the player's Attack/Abilities, and every ally's auto-attack, actually hit. If the targeted enemy dies, targeting automatically falls back to the next living one. Enemies, in turn, pick randomly among all living player-side combatants (the player plus any allies) each time they act, so allies can and will draw enemy attacks.

Allies are AI-controlled party members defined the same data-driven way as everything else: a new `AllyDefinition` `.tres` in `resources/allies/` (`id`, `display_name`, `stats`, `body_color`, `shape_points`) picked up automatically by `AllyRegistry`. They always auto-attack whichever enemy is currently targeted - there's no ally ability/action UI (see Known Limitations). Pass ally ids as the fourth argument to `SceneManager.start_combat(enemy_ids, return_scene, advances_encounter, ally_ids)` (or directly to `CombatManager.start(enemy_ids, ally_ids)`) to bring one into a fight; an ally being defeated doesn't end the combat, only the player dying does.

### Arrival spawn points

Every exploration scene used to have exactly one hardcoded `Player` position, used no matter which door the player actually came through - so leaving the Guild Lounge (whose only door is on its west wall) into the Adventure Centrum always dropped the player at the Centrum's single fixed spawn near *its* west wall (by the Plaza exit), regardless of which entrance made sense. `SceneManager.arriving_from_scene_path` now records which scene the player is leaving every time `goto_scene()` runs (read from `RunData.current_scene_path`, which every `ExplorationArea` already keeps current), and `ExplorationArea._apply_arrival_spawn()` (called first thing in `_ready()`) searches the new scene for an `EXIT` interactable whose `exit_target_scene` points back at that scene, then places the player a fixed distance inward from it (toward the room's center) instead of the scene's authored default. This needed no new per-scene data - it works retroactively for every exit pair already in the game - and falls back to the original fixed spawn whenever there's no such match (the start of a run, returning from combat, etc.).

### The Southside map

Exploration is now a small connected map, not a single room:

```
                                DeeperAlley (narrower, darker; the Sticky-Fingered Thug ambushes here)
                                    <-- one exit up -->            <-- one exit down -->
BackAlley (spawn point) -------------^                        UndergroundNerax (minimal stub, more to come)
    <-- one exit -->
TwoWayAlley (junction; has the alley trader)
    <-- one exit -->                    <-- other exit -->
  (back to BackAlley)                 Plaza (Nerax's central plaza; food vendor, swindler, adventurer NPC)
                                           <-- city gate -->        <-- guild hall door -->             <-- market exit -->
                                EncounterScreen (randomized run)   AdventureCentrum (loot sellers,     Market (long street, houses)
                                                                     receptionist, mission board)              |
                                                                        <-- lounge door (C-Rank+) -->    <-- southern gate -->
                                                                    GuildLounge (member-priced shop)   NeraxOutskirts (forest w/ bees
                                                                                                         east, lake west)
                                                                                                                |
                                                                       <-- deeper into the forest -->    <-- open path -->
                                                              MaskedManEncounter (first time only)     FarReaches (minimal stub)
                                                                        v
                                                                  DeepForest (bear + hunter, bigger)
```

Every `Interactable` of kind `EXIT` carries its own `exit_target_scene`, so the map graph is just data sitting in each scene file - there's no separate "level graph" resource to keep in sync. Add a new area by making a new `.tscn` + a two-line `ExplorationArea` subclass (see above) and pointing an `EXIT` interactable at it.

### Rushing enemies & the Deeper Alley

The Back Alley's south wall has a second gap (`DeeperAlleyExit`) leading to `scenes/world/DeeperAlley.tscn` - a narrower, darker passage that itself continues down into `scenes/world/UndergroundNerax.tscn` (intentionally a minimal one-room stub for now, not a dead end, ready for future content).

The Deeper Alley introduces a second, generic way for an exploration enemy to start a fight: `scripts/world/RushingEnemy.gd` (`class_name RushingEnemy`, a `CharacterBody2D`) is placed directly in a scene instead of an `Interactable` - it charges the player once they enter its `detection_radius` and forces combat on contact (`catch_radius`), with no interact key needed. `ExplorationArea` wires up every node in the `"rushing_enemies"` group automatically (mirroring `_connect_interactables()`/`Interactable`): `aggroed` shows `rush_notification` once, `rushed` starts combat via `enemy_ids`. Dropping a new ambush enemy into any area is just adding a `RushingEnemy` node with those fields set - no script changes.

The Deeper Alley's own threat, the **Sticky-Fingered Thug** (`resources/enemies/alley_robber.tres`), also introduces a new combat mechanic: a fleeing enemy. `EnemyDefinition.flees_after_turns` (5 here) makes an enemy bolt instead of acting once it's taken that many of its own turns, handled in `CombatManager._perform_flee()` - if the player has any gold, the thug steals `flee_steal_percent` (20%) of it on the way out (0 gold = nothing stolen) and combat ends the same as any other win, just with `CombatHUD` reporting the theft instead of a kill (`last_rewards["fled_enemies"]`/`["gold_stolen"]`) and no surprise-artifact roll (that roll is now gated on at least one enemy actually being defeated, not just "combat ended in your favor"). Killing him before he flees instead sets `RunData.story_flags["deep_alley_robber_defeated"]` via the new generic `EnemyDefinition.on_defeat_story_flag_id` field (fires automatically in `_on_enemy_defeated()` - no per-scene bookkeeping needed).

`DeeperAlley.gd` uses that flag directly to decide whether the thug shows up at all on each visit: guaranteed on the player's first-ever visit, a 20% chance on every visit after that as long as he's still alive (fled or never fought), and never again once `deep_alley_robber_defeated` is set.

### Story beats & the Back Alley Thug scenario

The back alley has a second, one-time combat encounter (in addition to the Alley Rat) that kicks off a short scripted sequence: beating the **Back Alley Thug** interactable there routes (via `Interactable.victory_return_scene`) to `scenes/world/CityGuardArrival.tscn` instead of back into the alley. That scene plays a short LoreIntro-style beat (text in `resources/lore/city_guard_arrival.tres`) - a City Guard of Nerax arrives, and more thugs show up looking for revenge - then starts a second fight (`["back_alley_thug", "back_alley_thug"]`) with the Guard fighting alongside the player as an ally. Winning that routes to `scenes/world/CityGuardFarewell.tscn` (text in `resources/lore/city_guard_farewell.tres`), a short beat where she asks where you live and assumes Southside before you can answer, before finally returning to the Back Alley for good.

This whole sequence only fires once per run: `Interactable.story_flag_id` ("back_alley_thug_defeated" here) is checked/set against `RunData.story_flags` (a generic `flag_id -> bool` bag, persisted with the run) the moment the interactable is triggered, and `ExplorationArea._connect_interactables()` hides/disables any interactable whose flag is already set on future visits. The same `story_flag_id` mechanism is reusable for any future one-shot story beat - it isn't specific to this scenario.

### The Rat Den & the Rat Boss

The Back Alley's `RatEncounter` interactable isn't a plain `COMBAT` trigger - `BackAlley.gd` overrides `_on_interactable_triggered()` to intercept it and computes its own enemy list each time instead of using a fixed one:

- Every trigger normally sends in 1 or 2 regular Alley Rats (picked randomly).
- `RunManager.get_counter("alley_rat_kills")` / `increment_counter()` (backed by `RunData.counters`, a generic `String -> int` bag added for exactly this kind of run-scoped tally) tracks total rats killed at this den across the whole run.
- Once that count reaches 5, every trigger instead rolls a chance to spawn the **Rat Boss** (`resources/enemies/rat_boss.tres`) with two Alley Rat escorts: 10% at 5 kills, +10% for every additional 5 kills racked up without having fought him yet (10 → 20%, 15 → 30%, ...), capped at 100%.
- Which fight was just sent into combat is stashed in `RunData` immediately before the scene switch (`story_flags["rat_den_pending_boss"]`, `counters["rat_den_pending_kills"]`) and resolved in `BackAlley._on_area_ready()` on return - returning to the Back Alley at all implies victory, since a loss routes to `RunSummary` instead and never comes back here. A boss win sets the permanent `story_flags["rat_boss_defeated"]` flag, after which the den stops spawning anything at all.

The boss fight itself exercises two new, fully generic `EnemyDefinition` miniboss fields (any future enemy can opt into either independently):

- `can_summon_minions` / `summon_minion_id`: each turn, if a minion sharing that id has died, the boss has a chance to use its action to revive it to full health instead of attacking (`CombatManager._has_defeated_minion()` / `_perform_summon_minion()`).
- `poison_attack_chance` / `poison_damage_per_turn` / `poison_duration_turns`: each turn, the boss also has a chance to land a weaker direct hit that additionally poisons the target (`CombatManager._perform_enemy_poison_attack()`). Poison itself is generic runtime state on `CombatUnitState` (`apply_poison()` refreshes rather than stacks) and ticks for flat, defense-ignoring damage at the start of the poisoned unit's own turn (`CombatManager._apply_poison_tick()`), which can finish off and grant kill rewards for anyone, player or enemy.

`EnemyDefinition.intro_quote` (logged once, before the usual "Combat begins against..." line, if any enemy in the fight has one set) is what plays the Rat Boss's angry entrance line. `EnemyDefinition.guaranteed_artifact_id` grants a specific artifact on defeat *in addition to* the normal random 35% drop roll (tracked separately in `CombatManager.last_rewards["guaranteed_artifacts"]` so it never collides with the single-slot random `"artifact"` key) - the Rat Boss guarantees **Rat King's Fang** (`resources/artifacts/rat_kings_fang.tres`), a stacking artifact (`VenomousFangEffect`) that gives every player attack a chance to poison its target using the same poison system, plus a large flat experience reward.

### Southside Market, the gate, and the outskirts

The Plaza has a third exit south (`ExitToMarket`) into `scenes/world/Market.tscn` - a long street lined with houses connecting the Plaza to Nerax's southern gate. Past the gate is `scenes/world/NeraxOutskirts.tscn`: forest to the east (bees nest by the old tree, near a repeatable `COMBAT` `Interactable` spawning 3 `forest_bee` at once - no escalation or respawn-chance logic like the Rat Den, just a plain always-available fight), a decorative lake to the west, and an open path south continuing to `scenes/world/FarReaches.tscn` - unlocked (no `required_guild_rank_order`), intentionally minimal for now, same "not a dead end" treatment as `UndergroundNerax.tscn`.

### Deeper into the forest: the masked man, and the Deep Forest

The forest zone hides one more thing: a `DeeperForestPathInteract` `EXIT`-flavored `Interactable` whose destination isn't fixed in the scene file - `NeraxOutskirts.gd` overrides `_on_interactable_triggered()` to check `RunData.story_flags["forest_portal_seen"]` and route to `scenes/world/MaskedManEncounter.tscn` the first time, or straight to `scenes/world/DeepForest.tscn` every time after.

**The masked man cinematic** (`MaskedManEncounter.gd`) follows the same click/Space/Enter-to-advance, Skip-to-jump-ahead pattern as `LoreIntro`/`CityGuardArrival`/`CityGuardFarewell` (all four share the identical `TextLabel`/`HintLabel`/`SkipButton`/`AdvanceArea` layout), but inserts a three-way choice partway through instead of just running linearly to a fixed next scene: after the intro text (a portal opens, a masked man taunts the player), it shows `DialogueChoicePopup` with custom labels "What?" / "Who are you?" / "Shut up." - the popup's existing custom-label support (already used for the guild receptionist's yes/no transaction) turns out to cover a three-way conversational choice just as well, no popup changes needed. "What?" and "Who are you?" both load the same calm epilogue (`masked_man_leaves.tres`); "Shut up" instead halves the player's *current* health (`RunManager.run.current_health / 2`, so it can never itself be lethal) before loading a different epilogue (`masked_man_shutup.tres`) - either way, finishing the epilogue text sets `forest_portal_seen` (done in `_ready()`, before the choice is even made) and transitions to `DeepForest.tscn`.

**Deep Forest** (`scenes/world/DeepForest.tscn`, bigger than the outskirts) has a sleeping bear (`forest_bear` - no special mechanics, just solid stats all around: 90 HP, 10 Attack, 8 Defense; a genuinely tough fight rather than a gimmick) on one side, one-shot and guaranteed to drop a **Bear Skin** (`resources/items/bear_skin.tres`) on defeat, and a hunter on the other. `DeepForest.gd` overrides `_on_interactable_triggered()` for the hunter to sequence three distinct states rather than branching purely on inventory: his "felt a disturbance, was that you?" icebreaker (`RunData.story_flags["hunter_greeted"]`) always plays first and exactly once, no matter whether the player already has the skin when they first talk to him; after that, every interaction offers to buy a currently-held skin for 50 gold, or shows a short idle line if the player isn't holding one. Selling to him removes the skin, pays the 50 gold, and permanently hides/disables him (`Interactable.story_flag_id = "hunter_bear_skin_sold"`, set the moment the sale succeeds) - he's genuinely gone after that, not just repeating himself. Declining ("Keep it") leaves him exactly as he was, so the player can still come back and sell to him later.

**Selling to any vendor.** The bear skin is also the first item to use `ItemDefinition.sell_price` (125 gold) - a new, deliberately separate field from the pre-existing `value` field (which nearly every item already has set as flavor/worth text, but which nothing had ever read). `ExplorationArea._try_sell_to_vendor()`, checked at the top of `_handle_trade()`, sells the first `sell_price > 0` item the player is carrying to *any* `TRADE`-kind `Interactable` instead of running that vendor's normal buy flow - so "sellable at every vendor" needed zero per-vendor configuration. (Reusing `value` for this instead was the first draft; a debug test caught that nearly every piece of equipment already had `value` set, which would have made everything in the player's pack sellable everywhere as an unintended side effect - `sell_price` defaults to 0 and is deliberately unset on anything else.)

### Using consumables outside combat now updates the HUD

Using an item from the Inventory screen while exploring updated `RunData.current_health`/`current_resource` correctly, but the `ExplorationHUD` bars weren't told to refresh (they only refresh in response to specific calls, not automatically) - the numbers were right the moment you reopened the panel, just stale on the bar underneath it until something else happened to trigger a refresh. `ExplorationArea._close_inventory()` now calls `hud.refresh_stats()` when the panel closes, which covers using a potion, equipping/unequipping, or anything else the panel changed.

### Dodge: a second Speed-driven combat formula

Bees introduce a second stat-comparison mechanic alongside the Attack-vs-Defense damage formula: `EnemyDefinition.dodge_uses_speed` (set on `forest_bee`) makes every attack against that enemy first roll `CombatManager.dodge_chance(attacker_speed, defender_speed)` - the exact same shape as `damage_multiplier()` (half a percent of chance per 1% Speed gap, same halving convention), but comparing Speed instead of Attack/Defense, capped at `MAX_DODGE_CHANCE_PERCENT` (90%), and interpreted as a complete miss (zero damage, no defense calculation at all) instead of a damage reduction. It only ever helps the *defender* - a defender with lower Speed than its attacker never dodges, mirroring how the damage formula never lets the weaker side "win." The check lives in `CombatManager._rolls_dodge()`, called from both `_perform_player_attack()` and `_ally_take_single_action()` (enemies attacking the player never check it, since only `enemy_def`-bearing units can hold the flag). Because it's gated on the flag rather than applied universally, existing enemies (including the deliberately-fast Sticky-Fingered Thug) are unaffected - only enemies that opt in via `dodge_uses_speed` get this passive.

### Trading

Both the Two-Way Alley (the "Back-Alley Trader") and the Plaza (a legitimate Food Vendor, and a "Shifty Peddler" reselling the same potion at a markup) have repeatable `Interactable`s of kind `TRADE` that sell `trade_item_id` for `trade_price` gold - `ExplorationArea._handle_trade()` checks the player has enough `RunData.currency`, then deducts it and adds the item. If the player holds the Thorned Coin artifact, its price is bumped by `ThornedCoinEffect.get_shop_price_multiplier()` - a hook that artifact always defined but that nothing called until these traders existed. An optional `trade_flavor_text` is appended to the purchase notification (the peddler's "extra effects, guaranteed" line is just flavor text - mechanically it sells the exact same `minor_healing_potion` the honest vendors do, just overpriced). Add a new vendor by dropping a `TRADE`-kind `Interactable` anywhere with `trade_item_id`/`trade_price` set.

### Dialogue & quests

The Plaza's "Traveling Adventurer" is an `Interactable` of kind `DIALOGUE`: interacting opens `DialogueChoicePopup` (`scenes/ui/DialogueChoicePopup.tscn`, added once per scene that needs it) with a fixed Yes / No / "Mind your own business" choice. `ExplorationArea._on_dialogue_choice()` shows the matching `dialogue_yes_text`/`dialogue_no_text`/`dialogue_decline_text`, and - only on Yes, and only if `quest_id` is set - starts that quest via `RunManager.start_quest()`. Talking again while the quest is active or after it's done shows `dialogue_quest_active_text`/`dialogue_quest_done_text` instead of repeating the pitch.

Quests are `QuestDefinition` resources (`resources/quests/*.tres`, loaded by `QuestRegistry`) tracked per-run in `RunData.active_quests`/`completed_quests`. `RunManager.complete_quest(quest_id)` grants any combination of `reward_gold`, `reward_exp`, `reward_stat_points`, `reward_item_ids`, a single `reward_artifact_id` and `reward_guild_progress` - unset fields just grant nothing, so a reward can be as small or as combined as the quest needs (a completed quest's gold also passes through the guild tax discount below, same as any other mission gold; **Find Wassim** below only sets `reward_exp`, so it grants exp and nothing else).

**Find Wassim**, the one "talk to a specific NPC" example, doesn't resolve by simply arriving somewhere - Wassim actually got himself arrested. He snuck into the Adventurers' Guild lounge without the rank for it and caused a scene, so he's being held there until someone sorts it out - which means the quest is naturally gated behind reaching C-Rank (the Lounge Door's existing `required_guild_rank_order`; no extra rank check was needed at Wassim himself, since merely reaching him already proves it). `GuildLounge.gd` overrides `_on_interactable_triggered()` to intercept a `WassimInteract` node (kind `MESSAGE`, but the default dispatch is bypassed) instead of using the default handling: talking to him while the quest is active gives his sob story ("I didn't know you needed rank for it, I swear") and calls `RunManager.complete_quest()` directly; talking again afterward just shows an idle line instead of re-granting the reward. Going back to the Traveling Adventurer in the Plaza afterward shows an updated `dialogue_quest_done_text` - he's adamant his brother did nothing wrong and will speak to the guards himself.

**Kill-count and repeatable quests**: `QuestDefinition.objective_enemy_id`/`objective_kill_count` describe a "kill N of this enemy" objective - `CombatManager._on_enemy_defeated()` calls `RunManager.register_enemy_kill_for_quests(enemy_id)` after every kill, which advances a per-quest counter (`RunData.counters["quest_kills_<id>"]`) for every active quest matching that enemy id and auto-completes (and logs the reward straight into the combat log) the moment the target count is hit - no separate "return to turn it in" step. `QuestDefinition.repeatable = true` means completing it clears active status without ever touching `completed_quests`, so `is_quest_completed()` stays false and the same offer (a `DIALOGUE` interactable, or the Mission Board below) can be accepted again immediately. The shipped example, **Kill the Bees** (`resources/quests/kill_the_bees.tres`), is both: repeatable, `objective_enemy_id = "forest_bee"`, `objective_kill_count = 9`.

The Adventure Centrum's existing "Quest Board" prop now doubles as the **Mission Board** - it's just a `DIALOGUE`-kind `Interactable` (`quest_id = "kill_the_bees"`) sitting on a board prop instead of talking to an NPC; no new `Interactable` kind was needed. Active/completed quests are listed on the pause menu's Character Info screen.

`DialogueChoicePopup.show_prompt(text, yes_label, no_label, decline_label)` accepts custom button text (pass `""` for `decline_label` to hide that button entirely) so the same popup doubles as a plain Yes/No confirmation - see the guild receptionist below for an example that isn't a conversation at all.

### Adventure Centrum & the Adventurers' Guild

The Adventure Centrum has its own small cast, all in `scenes/world/AdventureCentrum.tscn`:

- **Three loot-seller NPCs** (a traveling mage, a retired swordsman, a guild ranger) are plain `TRADE` interactables selling a weapon upgrade each - `travelers_blade`, `spare_apprentice_staff`, `rangers_secondary_bow` - all slightly-to-clearly better than the matching class's starting weapon, priced accordingly (the ranger's is priciest, per the request that started this feature).
- A **Guild Regular** is a `MESSAGE` interactable that just redirects newcomers to the receptionist.
- The **Guild Receptionist** is a new `Interactable` kind, `GUILD_RECEPTIONIST`, handled by `ExplorationArea._handle_guild_receptionist()`. If the player isn't enrolled, she offers to enroll them (F-Rank) for `GuildRankDefinition.upgrade_cost` gold; if already enrolled and not at the top rank, she offers to upgrade to the next one instead. Both offers reuse `DialogueChoicePopup` as a Yes/No confirmation.

The rank ladder itself is data: `GuildRankDefinition` resources under `resources/guild_ranks/` (F through S, loaded in order by `GuildRegistry`), each with `upgrade_cost`, `tax_discount_percent`, and which benefits it unlocks (`free_potion_per_mission`, `unlocks_lounge`, `unlocks_special_missions` - all cumulative, so B-Rank has everything D and C granted too). `RunData.guild_rank` holds the current rank id (`""` = not enrolled). Joining grants a `guild_membership_badge` item (a non-droppable `QUEST`-category item - proof of membership, not a mechanic by itself).

Two things read the rank ladder:
- `RunManager.complete_quest()` boosts `reward_gold` by `tax_discount_percent`, and adds a bonus Minor Healing Potion if the current rank's `free_potion_per_mission` is set ("missions" is scoped to quests for this MVP - see Known Limitations).
- `ExplorationArea._handle_trade()` applies the same `tax_discount_percent` as a price cut on any `TRADE` interactable with `lounge_pricing = true` (used by the two vendors in `GuildLounge.tscn`).

The **Lounge Door** in the Adventure Centrum is a normal `EXIT` interactable with `required_guild_rank_order` set to C-Rank's `order` (3) - `ExplorationArea` checks `RunManager.get_guild_rank_def()` before allowing the transition and shows `locked_message` instead if the requirement isn't met. `GuildLounge.tscn` sells a member-discounted potion and an exclusive `guild_reserve_longsword`. B-Rank's `unlocks_special_missions` flag is tracked but has no content behind it yet - see Known Limitations.

**Guild standing.** Testing for the next rank isn't just a gold cost anymore - it now also requires `RunData.guild_progress` (a second, separate accumulator, distinct from player exp/level) to have reached `RunManager.guild_progress_required(order)`, which mirrors `exp_required_for_level()`'s shape (`GUILD_PROGRESS_BASE * GUILD_PROGRESS_GROWTH^order`) but compounds 25% per rank instead of 10% per level. Enrollment (F-Rank, order 0) never requires standing - there's nothing to have proven yet. `ExplorationArea._handle_guild_receptionist()` checks this before even showing the paid-upgrade prompt, and reports current/required standing in a locked-style message if it's not met yet; on a successful upgrade the required amount is subtracted from `guild_progress` (overflow carries forward, same as exp past a level-up), not reset to zero. The only way to earn standing is `QuestDefinition.reward_guild_progress` - completing **Kill the Bees** grants 5 ("very low," and it's repeatable, so it's the intended grind for standing between the existing gold-cost upgrades).

### Character info & leveling, from the Inventory screen

Stat point allocation (and the rest of the character readout - level, exp, gold, guild rank, stats, quests) is available from **two** places now: the pause menu's existing "Character Info" button, and a new **Character** tab on the Inventory screen (`I`) itself - `InventoryScreen._populate_character()`/`_on_stat_point_pressed()` duplicate `PauseMenu`'s equivalent logic rather than sharing it, specifically so players who never find the pause-menu button (the original complaint) still discover unspent stat points immediately from the panel they're already used to opening.

### Leveling & experience

- `RunManager.grant_experience(amount)` adds experience and applies as many level-ups as the amount covers (each worth `RunManager.STAT_POINTS_PER_LEVEL`, currently 2, free stat points added to `RunData.unspent_stat_points`). The experience required for the next level is `RunManager.exp_required_for_level(level)` = 100 × 1.1^(level-1) - i.e. it grows 10% every level, compounding.
- `RunManager.compute_exp_reward(enemy_def)` scales the experience granted for a kill by the enemy's own `level` field and by how far above/below the player's level that enemy is (stronger-relative-to-you enemies are worth more, weaker ones worth less, floored so it's never zero) - see the function's doc comment for the exact formula and tuning knobs.
- Unspent points are spent one at a time via `RunManager.allocate_stat_point("hp"/"attack"/"defense"/"speed"/"intelligence")` - in the running game this is exposed on the pause menu's Character Info screen, which shows a button per stat whenever points are available. Spending on `"hp"` adds 10 max health (same ×10 convention as the class bonus); every other stat adds a flat +1.

### Gold

`RunData.currency` is the run's gold - enemies drop it (`EnemyDefinition.currency_reward`, boosted by the Thorned Coin artifact), treasure/event encounters grant or occasionally cost some, quests can reward it, and traders (see Trading, below) spend it. It's shown on the exploration HUD, the encounter screen, and the pause menu's Character Info panel.

### Add a class

1. Create a new `ClassDefinition` resource in `resources/classes/` (duplicate `resources/classes/ranger.tres` as a starting point).
2. Fill in `id`, `display_name`, `description`, `base_stats` (a `StatBlock` - start from the shared baseline of 50 HP / 5 / 5 / 5 / 5 and add +50 HP or +5 to exactly one other stat), `impact_stat` (display label of that one stat, e.g. `"Speed"` or `"HP"`), `resource_label` (e.g. "Fury"), `starting_equipment` (extra inventory item ids), `starting_equipped` (a `{slot: item_id}` dictionary, e.g. `{"weapon": "worn_sword"}`), `abilities` (ability ids - see below), `strengths`/`weaknesses`, and a `portrait_color`.
3. That's it - `ClassSelection.tscn` reads `ClassRegistry.get_all()` and lists whatever it finds.

To give the class new abilities, add `AbilityDefinition` `.tres` files to `resources/abilities/` the same way (set `ability_type`/`target_type` from the enums documented in `scripts/data/AbilityDefinition.gd`) and reference their `id`s in the class's `abilities` array.

### Add real artwork (replacing a placeholder polygon)

Every visual placeholder in the game (appearance options, enemies, allies) follows the same pattern: a `texture: Texture2D` field that's `null` by default (falls back to the colored polygon), and is preferred automatically the moment it's set. Nothing else needs to change - not the spawning code, not the registry, not the scene.

To give the Alley Rat real art, for example:

1. Drop the image file (e.g. `alley_rat.png`) anywhere under `resources/` - `res://resources/enemies/art/alley_rat.png` is a reasonable spot. Godot auto-imports any `.png`/`.jpg` it finds into a `Texture2D` the next time the project is opened (or, headless, the next `--editor --quit-after N` pass, same as after adding a new script).
2. Open `resources/enemies/alley_rat.tres` and add the texture reference. By hand, that means adding an `ext_resource` line for the image and pointing the enemy's `texture` field at it:
   ```
   [ext_resource type="Texture2D" path="res://resources/enemies/art/alley_rat.png" id="3_art"]
   ...
   [resource]
   ...
   texture = ExtResource("3_art")
   ```
   (bump `load_steps` by 1 to match, same as adding any other `ext_resource`.) If you'd rather not hand-edit the `.tres`, opening the same file in the Godot editor's Inspector and dragging the image onto the new `Texture` property does the identical thing.
3. That's it - `shape_points`/`body_color` are still there as the fallback (e.g. if you ever unset `texture`), but as long as `texture` is set, `EnemyCharacter` shows the real art everywhere that enemy appears (exploration marker and combat).

**Where every art asset type lives** (all under `resources/`, all follow the exact same texture-field pattern above):

```
resources/appearance/body/         - one file per body type (base skin layer)
resources/appearance/hair/         - one file per hairstyle
resources/appearance/shirts/       - upper clothing
resources/appearance/pants/        - lower clothing
resources/appearance/footwear/     - shoes
resources/appearance/skin_colors/  - color swatches only, never textures (see below)
resources/appearance/hair_colors/  - color swatches only, never textures
resources/enemies/                 - one file per enemy type
resources/allies/                  - one file per recruitable ally
```

**How many views does the game need? Just one.** There is currently no directional facing anywhere in the code - no `flip_h`, no up/down/left/right sprites, nothing (the player, enemies, and allies always render the same single static image no matter which way they're moving or who they're facing). So one image per layer/enemy/ally is all that's needed; you don't need a front view and a side view. If you'd like walking-direction flipping or facing sprites later, that's a real feature to build (cheap for left/right flipping via `Sprite2D.flip_h`, more work for a full 4-direction sprite set) - ask if you want it added.

**What view to draw**: since there's no turning, pick whatever reads best at a glance in a top-down game - most games like this use a **3/4 top-down angle** (viewed slightly from above, showing the top of the head/shoulders and the front of the body) rather than a flat front-on view, since that's the camera angle the player is always seen from while exploring. A straight front view also works and is simpler to keep consistent across a layered outfit system - either is legitimate, just be consistent across all your art.

**Image size**: there's no single hard-coded pixel size - final on-screen size is always `texture pixels × the Node2D scale wherever it's placed`, and that scale varies a lot by context:

| Context | Node/scene | Scale applied |
| --- | --- | --- |
| Player, exploring | `PlayerCharacter.gd` (`appearance.scale`) | 0.6x |
| Player, in combat | `CombatScene.tscn` `PlayerAppearanceRoot` | 2.2x |
| Player, character creator preview | `CharacterCreator.tscn` `PreviewRoot` | 3.0x |
| Enemy/ally, in combat | `CombatScene.tscn` `EnemyContainer`/`AllyContainer` | 1.6x |
| Enemy, exploration marker | per-instance, set on each `EnemyVisual` node | 0.8x-1.4x (varies per encounter) |

The existing placeholder polygons are quite small in raw units (the body shape is ~18x74 units at scale 1) because they were hand-drawn as tiny vector shapes - real art at that native resolution would look soft when scaled up 2-3x for combat/the creator preview. A good starting point: **draw humanoid layers (body/hair/shirt/pants/footwear) on a shared 128x128 or 256x256 transparent-background canvas**, and **enemies/allies on a 96x96 or 128x128 transparent canvas** (they only ever get scaled up to 1.6x, so they need less headroom than the player). Whatever size you pick, expect to retune the scale values in the table above by eye once real art is in the editor - they were calibrated for tiny polygons, not full-resolution art, and "does it look right" is the only real test.

**Critical: every layer of the same character must share the exact same canvas size and the character positioned identically within it.** `CharacterAppearanceRenderer` stacks `body`, `pants`, `shirt`, `footwear`, and `hair` directly on top of each other at the same position with no per-layer offset - so if the shirt art is centered differently than the body art on its own canvas, the shirt will visibly float in the wrong spot once equipped. Pick one canvas size for the whole appearance set and keep the character aligned the same way inside it on every layer (e.g. feet always at the same Y, always horizontally centered).

**Color tinting behaves differently for the player's layers vs. enemies/allies:**
- Body and hair layers are always modulated by the player's chosen **skin color** / **hair color** (`AppearanceOption.uses_skin_color`/`uses_hair_color`) - draw those in grayscale/white so the tint applies cleanly.
- Clothing layers (shirt/pants/footwear) are modulated by their own fixed `tint_color` (default white = shown as-painted, full color).
- Enemies and allies are **not** tinted at all once a `texture` is set - `body_color` only affects the placeholder polygon and is ignored the moment real art is assigned, so paint enemies/allies in their final, full colors directly.

### Add an enemy

1. Create a new `EnemyDefinition` resource in `resources/enemies/` (duplicate `resources/enemies/back_alley_thug.tres`).
2. Set `id`, `display_name`, `stats` (a `StatBlock`), `behavior_type` (`AGGRESSIVE` / `DEFENSIVE` / `RANDOM` - controls how often it defends instead of attacking), `loot_table` (array of `{"item_id": ..., "chance": 0.0-1.0}`), `xp_reward`, `currency_reward`, `body_color`, and a `shape_points` placeholder polygon.
3. It's now selectable by `EnemyRegistry.get_random_id()` (used by randomized combat encounters) and can be referenced by id from any `Interactable` with `kind = COMBAT` in an exploration scene.
   - **Real art instead of the placeholder polygon:** set the enemy's `texture` field (a `Texture2D`) and `EnemyCharacter` renders that `Sprite2D` instead of `shape_points`/`body_color` automatically - no other changes needed. Same field exists on `AllyDefinition`. See "Add real artwork" below for the exact steps.
4. Optional miniboss fields (all default to "off" for a plain enemy): `intro_quote` (a taunt logged once combat starts), `guaranteed_artifact_id` (a specific artifact granted on top of the normal random drop), `can_summon_minions`/`summon_minion_id` (revives a same-id fallen ally instead of attacking, when one is dead), and `poison_attack_chance`/`poison_damage_per_turn`/`poison_duration_turns` (a chance to poison its target for residual damage instead of a normal hit). See "The Rat Den & the Rat Boss" above for the shipped example of all four.
5. Optional fleeing-enemy fields: `flees_after_turns` (bolts instead of acting once it's taken this many of its own turns; 0 = never flees) and `flee_steal_percent` (fraction of the player's current gold stolen on a successful flee), plus the generic `on_defeat_story_flag_id` (set true in `RunData.story_flags` the moment this specific enemy is actually defeated, not fled). See "Rushing enemies & the Deeper Alley" above for the shipped example.
6. Optional `dodge_uses_speed` (every attack against this enemy rolls a Speed-based dodge chance instead of the normal damage formula - see "Dodge: a second Speed-driven combat formula" above).

### Add an artifact

1. **Data:** create a new `ArtifactDefinition` `.tres` in `resources/artifacts/` with `id`, `display_name`, `description`, `rarity`, `icon_color`, `effect_id` (a new string key), `effect_values` (whatever tuning numbers your effect needs), `stacking_allowed`, and optional `class_restrictions`.
2. **Behaviour:** create a new class under `scripts/artifacts/effects/` extending `ArtifactEffectBase`, overriding only the hooks it needs (`on_combat_started`, `on_player_attacked`, `on_enemy_defeated`, `get_passive_stat_modifier`, etc. - see the five existing effects for examples of each pattern).
3. **Wire it up:** add one `"your_effect_id": return YourEffect.new()` line to `ArtifactEffectFactory.create()`.

No existing artifact code needs to change.

### Add an item

Create a new `ItemDefinition` `.tres` in `resources/items/` with `category` (`WEAPON`/`ARMOR`/`CONSUMABLE`/`QUEST`), `rarity`, `icon_color`, `equip_slot` (`"weapon"`, `"offhand"`, `"armor"`, or `""`), `stat_modifiers` (a `StatBlock`, for equipment), and `heal_amount`/`resource_amount` (for consumables). It's immediately available to grant via loot tables, `Interactable` `ITEM` triggers, or a class's `starting_equipment`/`starting_equipped`.

### Add an encounter type or lore/dialogue text

Encounter kinds live in `resources/encounters/` (`EncounterEntry` resources: `kind`, `weight`, `display_name`, `flavor_text`) and are picked by weighted random roll in `EncounterRegistry.generate_sequence()`. Lore and other one-off dialogue text (the intro, the back-alley wake-up notification) live in `resources/lore/` as `LoreScript` resources (`sections: Array[String]`) - edit the array to change the words, no script changes.

### The defeat screen

`RunSummary.tscn` (shown after any run ends) now tracks the specific hit that killed the player, not just win/loss. `CombatManager.last_death_info` (`{"attacker_name", "attacker_level", "attack_label"}`) is overwritten on every hit the player takes - a normal attack, an enemy's poison attack, or a poison tick (which reads `CombatUnitState.poison_source_name`/`poison_source_level`, set when `apply_poison()` is called, so a delayed-DOT kill still credits whoever actually poisoned the player) - so whichever hit turns out to be fatal is always the most recent entry. `CombatHUD._on_result_confirmed()` passes it to `RunManager.end_run(false, death_info)`, which threads it into `last_run_summary` for the summary screen to read.

On defeat, the screen now shows a distinct red-bordered "Slain by X (Level N) - Killed with Y" card above the stats instead of folding that into a wall of text, "Enemies defeated" is a single number (not the full name list - the artifact list is unchanged), and there's a brief red screen-flash on load plus a slow ongoing pulse on the title while defeated (both skipped on victory, which keeps its plain fade-in).

### Artifact drop tuning

Two related changes, both prompted by Rat King's Fang (the Rat Boss's guaranteed reward) also being obtainable as a random drop from any old kill, which undercut it being a boss-specific prize: `ArtifactDefinition.random_drop_eligible` (default `true`) lets an artifact opt out of `ArtifactRegistry.get_random()` entirely while remaining reachable through a guaranteed source like `EnemyDefinition.guaranteed_artifact_id` - Rat King's Fang sets it to `false`. Separately, the flat chance for a random artifact on any victory (`CombatManager._grant_rewards()`) was lowered from 35% to 20%, making artifacts feel rarer across the board.

## Known limitations & suggested next steps

This is an MVP: the systems are real and reusable, but scope was intentionally kept small.

- **Placeholder visuals only.** Every sprite is a solid-color polygon. The layered appearance system and `AppearanceOption.texture` / `EnemyDefinition` fields are ready to accept real art without restructuring.
- **No manual ally control.** Allies (see "Targeting & allies" above) are always AI-controlled - they auto-attack whatever the player has targeted. Giving the player direct control over an ally's actions would be the natural next step if a future ally needs to do more than basic-attack.
- **No ability/item targeting beyond the current enemy target.** Every player and ally action goes through `CombatManager.get_current_target()`; there's no way to target, say, an ally with a heal, or hit "all enemies" even though `AbilityDefinition.TargetType.ALL_ENEMIES` exists as an enum value - it isn't wired up to any resolution logic yet.
- **Linear encounter sequence**, not a branching dungeon/map. `EncounterRegistry` already separates "what kinds of encounters exist" from "how the sequence is generated," so swapping in a graph/room-based generator later doesn't require touching the encounter resources.
- **No audio.** `AudioManager` and the settings UI are wired up; no sound assets are included.
- **Trading has no dedicated shop UI.** Buying is instant on interact (no browse/confirm screen) - fine for a single-item vendor, but a multi-item shop would want a proper menu.
- **Quests have no in-progress tracking beyond the pause menu list**, no quest markers/waypoints, and completion is currently always "arrive somewhere" or "talk to someone" - there's no generic "kill N enemies" or "collect N items" objective type yet, though `RunManager.complete_quest()` doesn't care *how* a quest gets marked active/complete, so adding one is mostly about calling `start_quest()`/`complete_quest()` from the right place.
- **"Guild tax" only discounts quest gold, not combat/encounter currency.** The guild rank system was built against the quest system specifically; extending the same `tax_discount_percent` to enemy `currency_reward`/encounter gold would mean applying it in `CombatManager`/`EncounterScreen` too.
- **B-Rank's "special missions" flag exists but has no content.** `GuildRankDefinition.unlocks_special_missions` is tracked and set correctly on B/A/S, but no quest currently checks it - it's there for a future quest (or a receptionist offer) to gate on.
- **Guild rank never goes down and can't be re-tested at a lower rank** other than starting a new run - there's no mechanic (missed payments, demotion, etc.) that would lower it.
- **No controller/touch input yet.** All input goes through the Input Map actions (`move_*`, `interact`, `pause_menu`, `inventory_toggle`, `ui_advance`), so adding a controller or on-screen touch layer means adding new bindings to those actions, not new code.
- **Basic AI.** Enemy behaviour is a simple probability roll (attack vs. defend) based on `behavior_type`; no positioning, focus-fire, or multi-turn planning.
- **Save migration is scaffolded but untested** - every save resource has a `save_version` field and the loaders already tolerate missing/corrupt files, but no old-format migration path exists yet (`RunData` is currently at v6; nothing reads older data specially, it just falls back to field defaults).
