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
scenes/world/FarReaches.tscn         - short connecting clearing south of the outskirts
scenes/world/WhisperingHollow.tscn   - sealed crystal cavern: Crystal Wisps, the Hollow Warden
scenes/world/GarrisonWard.tscn       - military district west of the Market: knights, a rushing assassin
scenes/world/MaskedManEncounter.tscn - one-time cinematic: a masked man taunts the player in the forest
scenes/world/DeepForest.tscn         - bigger forest beyond the portal: sleeping bear, hunter, a berry bush, a hidden trail
scenes/world/BugCatchersGrove.tscn   - hidden clearing off that trail: Bug Catcher Joe's camp
scenes/world/NeraxUpperWard.tscn     - Market's third exit; 3 beggars, one gives Swiftie Boots
scenes/world/InnerWallSouth.tscn     - guarded checkpoint gate: B-Rank+ or 100-gold toll
scenes/world/InnerNerax.tscn         - inner-city fountain plaza; 4 vendors, a 4-way hub
scenes/world/InnerNeraxShops.tscn    - the inner market's shopping street: 4 shopfronts, road north
scenes/world/ButcherShop.tscn        - The Fatted Cleaver: combat_usable=false meat cuts
scenes/world/AlchemistShop.tscn      - The Gilded Retort: potions + 5 one-shot single-stat elixirs
scenes/world/ClothingShop.tscn       - Silks & Seams: restyle appearance for 30 gold
scenes/world/RelicShop.tscn          - The Curious Case: basic gear + 2 exclusive relics
scenes/world/GuardsRushCutscene.tscn - one-time cinematic: guards rushing to the Royal Castle
scenes/world/CentralWallSmokeCutscene.tscn - one-time cinematic: smoke over the central wall
scenes/world/CentralNeraxWard.tscn   - checkpoint at Central Nerax's wall; dead end for now
scenes/world/MercenaryCamp.tscn      - Plaza's second west exit; the Flankers (3-mercenary fight)
scenes/world/EastCheckpoint.tscn     - Plaza's second east exit; 4-mercenary toll ultimatum
scenes/world/EasternRoad.tscn        - past the checkpoint; dead end for now
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

The class resource pool (mana/stamina/energy) is not stored directly - it's always derived at read time in `RunManager.compute_current_stats()` as `Intelligence * RunManager.MANA_PER_INTELLIGENCE` (10) **plus** `Attack * RunManager.STAMINA_PER_ATTACK` (5), plus any flat bonuses from equipped items/artifacts. The Attack term exists so a build that never invests in Intelligence (a Knight leaning purely into Attack, say) still grows a usable resource pool instead of being stuck near the base value - raising either stat (by class bonus, leveling, or gear) raises the resource pool.

### Combat damage formula

`CombatManager.damage_multiplier()` (a pure static function, easy to unit-test or retune) implements the attack-vs-defense comparison:

- Base damage comes from **Attack** for weapon attacks and non-magic abilities, or a blend of **50% Attack + 25% Intelligence** for abilities marked `uses_intelligence = true` ("spells"), multiplied by the ability's `power`.
- The attacker's raw **Attack** stat is then compared against the defender's *effective* Defense (`CombatUnitState.get_effective_defense()` = Defense × (1 + any active Defend/Guard bonus)): equal stats mean no change; every 1% the attacker's Attack exceeds the defender's Defense adds half a percent of bonus damage, and every 1% the defender's Defense exceeds the attacker's Attack cuts half a percent of damage - exactly mirroring each other. This is clamped to +300%/-90% as a safety bound (see the constants at the top of `CombatManager.gd`) so an extreme stat gap can't produce a runaway or negative result; a 1-damage floor still applies underneath that in `CombatUnitState.apply_damage()`.
- Critical hits (from artifacts like Hunter's Eye) apply their multiplier before the defense comparison; artifact flat bonuses (like Cinder Ring) are added to the base damage before that too - defense scales the whole finished hit, source included.

### Turn order & speed

Turns are not a simple alternating queue. At the start of each round, `CombatManager._begin_new_round()` finds the slowest living combatant (player included) and gives every combatant `floor(their_speed / slowest_speed)` actions for that round (minimum 1) - so double the slowest Speed means two actions per round, triple means three, and so on. Combatants then act in descending action-count order, each one using its whole block of actions consecutively before the next combatant's block starts (with a single enemy this reduces exactly to "faster side bursts, slower side gets one hit, repeat"). The ratio is recalculated fresh every round, which is what makes this ready for future speed buffs/debuffs "later," per the request that started this feature - a mid-combat effect just needs to change `speed` on the relevant `CombatUnitState` and the next round picks it up automatically. `CombatHUD` shows a "(2/4)" style counter during multi-action blocks (`CombatManager.get_current_block_progress()`).

### The turn-order wheel

`CombatHUD` shows a "speed wheel" strip just under the health bar - a row of small round tokens, current actor first, each one further out shrinking and fading so the strip reads "soon → later" at a glance. It's driven entirely by `CombatManager.get_upcoming_turn_order(max_count)`, which reads the rest of the live `_round_queue` (skipping anyone who's died since it was built) and, if that runs out, previews a hypothetical next round computed from the currently-alive combatants via `_compute_round_order()` - the same speed-ratio algorithm `_begin_new_round()` itself uses, factored out so the UI can preview it without committing to it. That preview is a best-effort approximation (it assumes nobody's speed changes before the round actually starts), same spirit as the class's existing "recalculated fresh every round" behavior.

Each token is a colored circular badge - real artwork if the unit has a `texture` set (see "Add real artwork" below), otherwise its name's first letter over its team color (`ClassDefinition.portrait_color` for the player, `body_color` for enemies/allies) - gold-bordered and enlarged for whoever's acting right now. It only rebuilds (with a staggered pop-in animation per token) on `turn_changed`, not on every `stats_changed`, so it updates once per actual turn instead of replaying its entrance animation on every individual damage tick.

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
BackAlley (spawn point) -------------^                        UndergroundNerax (4 thugs + mage, a trader,
    <-- one exit -->                                                            an informant, then the Warlord)
TwoWayAlley (junction; has the alley trader)
    <-- one exit -->                    <-- other exit -->
  (back to BackAlley)                 Plaza (Nerax's central plaza; food vendor, swindler, adventurer NPC)
                                           <-- city gate -->        <-- guild hall door -->             <-- market exit -->
                                EncounterScreen (randomized run)   AdventureCentrum (loot sellers,     Market (long street, houses,
                                                                     receptionist, mission board)        a vendor, a resident)
                                                                        <-- lounge door (C-Rank+) -->    |              |
                                                                    GuildLounge (member-priced shop)     |         <-- southern gate -->
                                                              <-- west exit -->                          |       NeraxOutskirts (forest w/ bees
                                                        GarrisonWard (knight, mercenary,                 |        east, lake west)
                                                         a rushing assassin - D-Rank mission)             |              |
                                                                                                    (back to Plaza)  <-- deeper into the forest -->    <-- open path -->
                                                                                                                    MaskedManEncounter (first time only)     FarReaches
                                                                                                                              v                                     |
                                                                                                                        DeepForest (bear + hunter, bigger)    <-- crack in the earth -->
                                                                                                                                                             WhisperingHollow (wisps + Warden)
```

Market's south wall carries a second gap alongside its Plaza exit (the same double-gap technique used everywhere else in the game) - "Ward Stairs" up into `NeraxUpperWard.tscn`, which itself continues north into `InnerWallSouth.tscn` and, through its guarded gate, `InnerNerax.tscn` - a fountain plaza whose north exit (via a one-time cinematic) leads to `InnerNeraxShops.tscn` and its four shop interiors (`ButcherShop.tscn`, `AlchemistShop.tscn`, `ClothingShop.tscn`, `RelicShop.tscn`), which itself continues north (via a second cinematic) to `CentralNeraxWard.tscn`. The whole chain reads as one continuous push north/up into the city, not a detour east - Market's own north wall now leads straight on to the (still so-named) southern gate and the outskirts, so entering Market from the Plaza and continuing "further north" reaches Ward Stairs and beyond. See "The Upper Ward, a beggar's gift, and the inner wall" below.

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

The Plaza has a third exit north (`ExitToMarket`) into `scenes/world/Market.tscn` - a long street lined with houses connecting the Plaza to Nerax's southern gate (a name kept for flavor; the road itself now runs north out of the Plaza), now with two residents of its own: a **Market Vendor** (`TRADE`, sells `minor_mana_potion` - a second, surface-level source for it so players don't have to trek all the way to the Underground trader just to restock) and a **Local Resident** (`MESSAGE`, gossiping about the strange lights and sealed cave further south - a bit of connective flavor text pointing at the Whispering Hollow before the player's even reached the outskirts). Past the gate is `scenes/world/NeraxOutskirts.tscn`: forest to the east (bees nest by the old tree, near a repeatable `COMBAT` `Interactable` spawning 3 `forest_bee` at once - no escalation or respawn-chance logic like the Rat Den, just a plain always-available fight), a decorative lake to the west, and an open path south continuing to `scenes/world/FarReaches.tscn`, itself now leading on to the Whispering Hollow (see below).

### The Garrison Ward: haste, a rushing assassin, and D-Rank's mission

The Market has a second new exit, this time west (`ExitToGarrison`, its own wall-split following the same top/bottom-gap pattern used everywhere else, just rotated onto the left wall) into `scenes/world/GarrisonWard.tscn` - a military district, freely explorable at any rank. A knight and a mercenary (both plain `MESSAGE` NPCs) discuss half the Southside garrison being pulled north on the Crown's orders, and a posted decree makes it official - scene-setting for a bigger threat than one assassin, without committing to what it is yet.

**A genuine ambush, not a walk-up fight.** The Masked Assassin is a `RushingEnemy` (the same mechanic the Deeper Alley robber uses) lurking in the ward - strong stats, `dodge_uses_speed` (fitting, for an assassin), and a new signature move.

**Haste - the mirror image of the ice mage's freeze.** `EnemyDefinition.haste_spell_chance`/`haste_multiplier`/`haste_duration_rounds` reuse the exact same mechanism the freeze debuff already uses (`CombatUnitState.apply_speed_debuff()`/`get_effective_speed()`) - just with a multiplier above 1.0 instead of below it, so no new state was needed on the unit at all. Casting it costs the assassin his whole turn (no attack that turn), and `CombatManager._enemy_take_single_action()` guards against recasting it while already hasted (checked via `speed_debuff_turns_remaining > 0`), so it reads as a real "burst window" that has to wear off first rather than something he can chain forever. Verified: casting doubles his effective Speed for exactly 4 rounds, decaying back to normal on schedule, and forcing the cast chance to 100% while already hasted still doesn't recast it - he attacks normally instead.

Defeating him resolves **A Blade in the Dark** if it's active - offered by a new **Watch Sergeant** NPC back in the Market, D-Rank and up (`required_guild_rank_order = 2`), using the exact same rank-gated-`DIALOGUE` mechanism described below. Same "return here implies it happened" completion pattern as The Guild's Grudge: `GarrisonWard.gd._check_blade_quest_completion()` checks `RunData.story_flags["city_assassin_defeated"]` (set automatically by his `on_defeat_story_flag_id`) every time the scene loads, and the same flag also permanently `queue_free()`s the `RushingEnemy` node so he doesn't come back.

### Rank-gated missions, and three more guild missions

`Interactable` already had `required_guild_rank_order`/`locked_message` for gating `EXIT` transitions (the Guild Lounge door) - `ExplorationArea._open_dialogue()` now checks the exact same two fields before showing a `DIALOGUE` quest-giver's prompt at all, so a quest-giver NPC can be rank-gated with zero new data fields, just by setting `required_guild_rank_order` on its `Interactable`. Below E-Rank, talking to a gated NPC shows the `locked_message` instead of the pitch; the quest is never even offered, not just hidden after the fact.

Two new missions use this:
- **The Guild's Grudge** (Underground) - a new NPC, the **Frightened Merchant**, hiding just past the entrance (his own `Interactable` is the one with `required_guild_rank_order = 1`). Accepting posts a bounty on the Underground Warlord; completion isn't kill-count or arrival-based like earlier quests, but a third pattern - `UndergroundNerax.gd._check_grudge_quest_completion()` checks the quest is active and `RunData.story_flags["underground_boss_defeated"]` (already set by the Warlord's own `on_defeat_story_flag_id`) every time the scene loads, same "return here implies it happened" convention `_check_boss_trigger()` already uses.

**Wolf Cull** (offered by the **Guild Receptionist** in the Adventure Centrum, not a field-gated quest-giver): originally lived on the Deep Forest Hunter, but the Hunter can permanently vanish - selling him the bear skin makes him leave for good (`visible`/`monitorable`/`monitoring` all cleared, persisted via `story_flag_id`), which could soft-lock the quest for the rest of the run if that happened before the wolf offer was ever seen. `AdventureCentrum.gd._talk_to_receptionist()` now offers it (E-Rank+, inline check, same condition the Hunter used to gate on) ahead of her normal enrollment/rank-up business whenever it's available, falling through to `_handle_guild_receptionist()` otherwise - a repeatable "cull 7 Forest Wolves" mission against the pack enemy at `resources/enemies/forest_wolf.tres` (`WolfPackInteract` in Deep Forest, 2 at a time, same pattern as the bee/wisp swarms). The Hunter himself is back to just the icebreaker and the bear-skin sale.
- **Pest Control**, **Into the Hollow** → **Hollow Menace** - covered above and below; all of these plus Kill the Bees now feed the same `RunData.guild_progress` pool.

### The Deep Forest expands: Bug Catcher Joe and a new heal-seal mechanic

Three new interactables in `DeepForest.tscn`: a one-time **Berry Bush** (`ITEM`, grants 2x the new `wild_berries` consumable, a minor 6-health snack cheaper than Meat Pie), a **Weathered Sign** (`MESSAGE`, "PRIVATE - TRAPS SET" flavor foreshadowing what's ahead), and a **Hidden Trail** (`EXIT`, easy to miss, tucked in the southeast corner - no wall gap needed since it's a path through the brush, not a door) leading to a brand-new connected scene, `scenes/world/BugCatchersGrove.tscn`.

The Grove is **Bug Catcher Joe**'s camp - a lean-to, cracked specimen jars, and a one-shot fight against him and his swarm (`JoeInteract`, `enemy_ids = ["joe_bug_catcher", "forest_bug", "forest_bug", "forest_bug"]`). The three `forest_bug` minions are individually trivial (14 HP, 5 Attack) but Joe himself is a real threat (105 HP/15 Attack/11 Defense - tougher across the board than the Sleeping Bear). Two more interactables round out the clearing: **Overturned Jars** and the **Makeshift Camp** (both flavor `MESSAGE`s) and a one-time **Prize Specimen** pickup (`ITEM`, the new `iridescent_beetle_shell` trophy - `sell_price = 40`, sellable at any vendor like the bear skin/crystal shards).

### Small touches across town, the Underground, and every earlier area

A pass of light, low-risk flavor and loot additions across every previously-built scene - all using the same generic `MESSAGE`/`ITEM` `Interactable` kinds `ExplorationArea` already handles, so none of it needed new mechanics or script overrides, just new nodes:

- **Plaza**: a **Street Performer** (`MESSAGE`, pure color) and **Fountain Floor** (`ITEM`, one-time, sifts up the new `lucky_coin` trophy - `sell_price = 15`).
- **Market**: a **Stray Cat** (`MESSAGE`), wandering the stalls and ignoring the player entirely.
- **Adventure Centrum**: a **Trophy Wall** (`MESSAGE`) referencing the bear and the wolves - a small nod to what the player's already done by the time they'd plausibly see it.
- **Guild Lounge**: an **Off-Duty Guard** (`MESSAGE`) grumbling about the Garrison Ward redeployment - ties back to the Knight/Mercenary dialogue already in `GarrisonWard.tscn`.
- **Deeper Alley**: a one-time **Stashed Satchel** (`ITEM`, a spare `minor_healing_potion`) - required adding a `CircleShape2D` interact shape to this scene, since it previously had no `MESSAGE`/`ITEM`-kind interactables at all.
- **Underground Nerax**: a **Hidden Stash** (`ITEM`, 2x `minor_mana_potion`) and a **Warning Scrawl** (`MESSAGE`) about the Warlord's heal-and-recover phase, foreshadowing the fight for anyone who reads it first.
- **Nerax Outskirts**: **Lake Shallows** (`ITEM`, one-time, another `lucky_coin` - reusing the same item from the Plaza fountain rather than minting a near-identical one).
- **Whispering Hollow**: an **Old Miner's Pack** (`ITEM`, one-time `minor_healing_potion`) tucked away from the main path.

Verified by instantiating all eleven new interactables inside their real scenes and calling `.trigger()` directly: every `ITEM` one grants the right item/quantity and sets its story flag (so it can't be re-triggered), every `MESSAGE` one fires without error, and the full scene-boot regression sweep stays clean project-wide.

Joe's gimmick is a brand-new mechanic, **heal seal**: `EnemyDefinition.seals_healing_when_alone` (checked by `CombatManager._check_heal_seal()`, called from `_on_enemy_defeated()`) triggers the instant an enemy becomes the last one standing in the fight - i.e. every enemy present at combat start other than itself is dead. For Joe that means the moment his third and final bug falls while he's still alive, regardless of order. It sets a new `CombatUnitState.heal_sealed` flag on the player, permanently for the rest of that combat, which is then checked at all three places player healing can happen: `player_use_item()` (health potions - blocked before the item is even consumed, so nothing's wasted), the `HEAL` branch of `player_use_ability()`, and `heal_player()` (the shared entry point artifacts like Moonstone Charm and Warlord's Renewal already heal through) - so "no potions, no artifacts, no abilities" all come from one flag and three matching guards rather than three separate mechanics. Defeating Joe himself guarantees a new artifact, **Bug Catcher's Net** (`+6 Speed`, passive, `random_drop_eligible = false` like every other named boss drop).

### The Whispering Hollow, and two new guild missions

`FarReaches.tscn` (previously a genuine dead-end stub) now leads somewhere: a crack in its south wall opens into `scenes/world/WhisperingHollow.tscn`, a sealed crystal cavern. Repeatable Crystal Wisps drift freely (a `COMBAT` interactable spawning 3 at once, same pattern as the forest bees), an old inscription hints at why the cavern was sealed at all, and the Hollow Warden waits at the back - a one-shot boss guaranteeing **Heart of the Hollow** (a passive Legendary artifact, +8 Defense/+6 Intelligence, `random_drop_eligible = false`) and two **Crystal Shards** (a new trophy item, `sell_price = 90`, sellable at any vendor the same way the Deep Forest's bear skin already is).

**A new combat mechanic, from the Crystal Wisps: a one-time shield.** `EnemyDefinition.absorbs_first_hit` negates the very first hit an enemy takes each combat entirely (`CombatUnitState.has_absorbed_hit`, `CombatManager._rolls_shield()`) - structurally the same one-time-guard shape as the enrage/dodge checks, just unconditional on the first hit rather than a per-hit roll. Checked at the same call sites as `_rolls_dodge()`, so it composes with dodge automatically for any future enemy that has both. Verified: the first attack against a wisp is fully absorbed and shatters the shield; every attack after that lands normally.

**Two new missions**, both posted from the Adventure Centrum and both feeding `RunData.guild_progress` (see the Adventurers' Guild section above) the same way Kill the Bees already does:
- **Pest Control** (Junior Clerk, a new NPC) - repeatable, kill 6 `alley_rat`. A low-stakes F-Rank-friendly starter mission using nothing but the existing kill-count quest machinery.
- **Into the Hollow** / **Hollow Menace** - a small two-quest chain through one new NPC, **Guild Scout Elin**. `AdventureCentrum.gd` overrides `_on_interactable_triggered()` for her (same pattern as the Deep Forest hunter's inventory-dependent dialogue): she offers the one-shot "scout the cavern" quest first (completed on arrival at the Hollow, same "explore this place" pattern Find Wassim uses), and once that's done, always offers the repeatable "cull 8 Crystal Wisps" follow-up instead - a lightweight, reusable way to chain quests through a single NPC without a new dialogue system.

### The Underground: four thugs, a trader, and the Warlord

`UndergroundNerax.tscn` (beneath the Deeper Alley) grew from a one-room stub into a real fight: four separate `COMBAT` interactables (three regular thugs, one mage miniboss), each one-shot with its own `story_flag_id` so they can be fought in **any order**, plus a `TRADE` interactable selling Minor Mana Potions (`resources/items/minor_mana_potion.tres`, restores the class resource instead of health). Interacting with any of them is the "anger" - `EnemyDefinition.intro_quote` supplies each one's taunt, logged the instant combat starts.

**Two new generic combat mechanics, introduced by the mage:**
- **A Speed debuff ("frozen").** `EnemyDefinition.ice_spell_chance`/`ice_freeze_chance`/`ice_freeze_multiplier`/`ice_freeze_duration_rounds` - a low-damage spell with a chance to multiply the target's Speed (`CombatUnitState.apply_speed_debuff()`/`get_effective_speed()`) for a few rounds. Every place Speed previously mattered (`_compute_round_order()`'s turn ordering, `dodge_chance()`) now reads `get_effective_speed()` instead of raw `speed`, so a frozen unit visibly acts less often and dodges worse without any special-casing elsewhere. Debuffs tick down once per round (`_begin_new_round()`), not per-turn like poison, since Speed only matters for round-wide ordering.
- **A shared kill counter driving an instant boss ambush.** `EnemyDefinition.on_defeat_counter_id` increments a `RunData.counters` key on defeat - all four underground enemies point at the same `"underground_thugs_defeated"` key. `UndergroundNerax.gd._check_boss_trigger()`, run every time the scene loads (including the instant the player returns from whichever fight happened to be the last one), starts the boss fight automatically once that counter hits 4 - so it genuinely doesn't matter which of the four is defeated last.

**The Underground Warlord** (`resources/enemies/underground_boss.tres`) introduces two more generic mechanics:
- **A charge attack.** `EnemyDefinition.charges_before_attack` (2 here) makes an enemy spend that many of its own turns winding up (logged, no damage) before the next one actually lands a hit (`CombatUnitState.charge_progress`) - a bulky, slow-hitting boss without needing a bespoke state machine.
- **An enrage phase.** `EnemyDefinition.enrages_below_health_percent`/`enrage_heal_percent`/`enrage_summon_id`/`enrage_summon_count` - a one-time (`CombatUnitState.has_enraged` guard) self-heal plus fresh reinforcements, checked (`CombatManager._check_enrage()`) everywhere an enemy takes damage, same call sites as the existing `_check_health_low()`. The reinforcements are just appended to `enemy_units` - `_begin_new_round()` already rebuilds the turn order from living combatants every round, so they're included automatically; only the *visuals* need telling, via a new `roster_changed` signal that `CombatScene` uses to re-spawn enemy tokens.

Defeating him drops **Warlord's Renewal** (`guaranteed_artifact_id`, rarity Legendary, `random_drop_eligible = false`) - a relic that mirrors his own mechanic back at the player, toned down: once per combat, the moment the player's health drops low (`EventBus.health_low`, the same 30%-threshold event several other systems already react to), it heals them for 25% of max health (`WarlordsRenewalEffect.gd`, `on_health_low` hook, one-shot guard reset on `on_combat_started`).

The mage also guarantees its own rewards on defeat: `EnemyDefinition.guarantees_random_artifact` (a new flag, distinct from `guaranteed_artifact_id`) grants a random artifact from the normal pool instead of a fixed one, and its `loot_table` uses four separate 100%-chance entries for the same item to guarantee exactly four Minor Healing Potions - no new data structure needed for either.

### Deeper into the forest: the masked man, and the Deep Forest

The forest zone hides one more thing: a `DeeperForestPathInteract` `EXIT`-flavored `Interactable` whose destination isn't fixed in the scene file - `NeraxOutskirts.gd` overrides `_on_interactable_triggered()` to check `RunData.story_flags["forest_portal_seen"]` and route to `scenes/world/MaskedManEncounter.tscn` the first time, or straight to `scenes/world/DeepForest.tscn` every time after.

**The masked man cinematic** (`MaskedManEncounter.gd`) follows the same click/Space/Enter-to-advance, Skip-to-jump-ahead pattern as `LoreIntro`/`CityGuardArrival`/`CityGuardFarewell` (all four share the identical `TextLabel`/`HintLabel`/`SkipButton`/`AdvanceArea` layout), but inserts a three-way choice partway through instead of just running linearly to a fixed next scene: after the intro text (a portal opens, a masked man taunts the player), it shows `DialogueChoicePopup` with custom labels "What?" / "Who are you?" / "Shut up." - the popup's existing custom-label support (already used for the guild receptionist's yes/no transaction) turns out to cover a three-way conversational choice just as well, no popup changes needed. "What?" and "Who are you?" both load the same calm epilogue (`masked_man_leaves.tres`); "Shut up" instead halves the player's *current* health (`RunManager.run.current_health / 2`, so it can never itself be lethal) before loading a different epilogue (`masked_man_shutup.tres`) - either way, finishing the epilogue text sets `forest_portal_seen` (done in `_ready()`, before the choice is even made) and transitions to `DeepForest.tscn`.

**Deep Forest** (`scenes/world/DeepForest.tscn`, bigger than the outskirts) has a sleeping bear (`forest_bear` - no special mechanics, just solid stats all around: 90 HP, 10 Attack, 8 Defense; a genuinely tough fight rather than a gimmick) on one side, one-shot and guaranteed to drop a **Bear Skin** (`resources/items/bear_skin.tres`) on defeat, and a hunter on the other. `DeepForest.gd` overrides `_on_interactable_triggered()` for the hunter to sequence three distinct states rather than branching purely on inventory: his "felt a disturbance, was that you?" icebreaker (`RunData.story_flags["hunter_greeted"]`) always plays first and exactly once, no matter whether the player already has the skin when they first talk to him; after that, every interaction offers to buy a currently-held skin for 50 gold, or shows a short idle line if the player isn't holding one. Selling to him removes the skin, pays the 50 gold, and permanently hides/disables him (`Interactable.story_flag_id = "hunter_bear_skin_sold"`, set the moment the sale succeeds) - he's genuinely gone after that, not just repeating himself. Declining ("Keep it") leaves him exactly as he was, so the player can still come back and sell to him later.

**Selling to any vendor.** The bear skin is also the first item to use `ItemDefinition.sell_price` (125 gold) - a new, deliberately separate field from the pre-existing `value` field (which nearly every item already has set as flavor/worth text, but which nothing had ever read). Any item with `sell_price > 0` (or, failing that, a plain `value > 0`) is sellable to *any* `TRADE`-kind `Interactable` - originally via an auto-sell that fired on interact, later replaced by `TraderScreen`'s Sell tab (see "A proper trader screen" below) - so "sellable at every vendor" needed zero per-vendor configuration. (Reusing `value` for this instead of a dedicated field was the first draft; a debug test caught that nearly every piece of equipment already had `value` set, which would have made everything in the player's pack sellable everywhere as an unintended side effect - `sell_price` defaults to 0 and is deliberately unset on anything else.)

### Using consumables outside combat now updates the HUD

Using an item from the Inventory screen while exploring updated `RunData.current_health`/`current_resource` correctly, but the `ExplorationHUD` bars weren't told to refresh (they only refresh in response to specific calls, not automatically) - the numbers were right the moment you reopened the panel, just stale on the bar underneath it until something else happened to trigger a refresh. `ExplorationArea._close_inventory()` now calls `hud.refresh_stats()` when the panel closes, which covers using a potion, equipping/unequipping, or anything else the panel changed.

### Dodge: a second Speed-driven combat formula

Bees introduce a second stat-comparison mechanic alongside the Attack-vs-Defense damage formula: `EnemyDefinition.dodge_uses_speed` (set on `forest_bee`) makes every attack against that enemy first roll `CombatManager.dodge_chance(attacker_speed, defender_speed)` - the exact same shape as `damage_multiplier()` (half a percent of chance per 1% Speed gap, same halving convention), but comparing Speed instead of Attack/Defense, capped at `MAX_DODGE_CHANCE_PERCENT` (90%), and interpreted as a complete miss (zero damage, no defense calculation at all) instead of a damage reduction. It only ever helps the *defender* - a defender with lower Speed than its attacker never dodges, mirroring how the damage formula never lets the weaker side "win." The check lives in `CombatManager._rolls_dodge()`, called from both `_perform_player_attack()` and `_ally_take_single_action()` (enemies attacking the player never check it, since only `enemy_def`-bearing units can hold the flag). Because it's gated on the flag rather than applied universally, existing enemies (including the deliberately-fast Sticky-Fingered Thug) are unaffected - only enemies that opt in via `dodge_uses_speed` get this passive.

### Trading

Both the Two-Way Alley (the "Back-Alley Trader") and the Plaza (a legitimate Food Vendor, and a "Shifty Peddler" reselling the same potion at a markup) have repeatable `Interactable`s of kind `TRADE` that sell `trade_item_id` for `trade_price` gold. Interacting with any `TRADE` interactable opens `scenes/ui/TraderScreen.tscn` - a shared, tabbed panel (Buy / Sell) rather than an inline popup - see "A proper trader screen" below for the full shape of it. An optional `trade_flavor_text` is appended to the purchase notification (the peddler's "extra effects, guaranteed" line is just flavor text - mechanically it sells the exact same `minor_healing_potion` the honest vendors do, just overpriced). Add a new vendor by dropping a `TRADE`-kind `Interactable` anywhere with `trade_item_id`/`trade_price` set - no scene needs its own `DialoguePopup` for this anymore, `TraderScreen` is instantiated once per exploration area automatically.

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
7. Optional fields from the Underground Warlord fight: `ice_spell_chance`/`ice_freeze_chance`/`ice_freeze_multiplier`/`ice_freeze_duration_rounds` (a Speed-debuffing spell), `charges_before_attack` (needs N of its own turns to land one hit), `enrages_below_health_percent`/`enrage_heal_percent`/`enrage_summon_id`/`enrage_summon_count` (a one-time self-heal-plus-reinforcements phase), `guarantees_random_artifact` (a random, not fixed, guaranteed drop), and `on_defeat_counter_id` (bumps a shared `RunData.counters` key on defeat - lets several different enemies contribute to one tally). See "The Underground: four thugs, a trader, and the Warlord" above for the shipped example of all of them.
8. Optional `absorbs_first_hit` (negates the very first hit this enemy takes each combat, then behaves normally - see "The Whispering Hollow" above).
9. Optional `haste_spell_chance`/`haste_multiplier`/`haste_duration_rounds` (a self-buff that spends its turn to multiply its own Speed for a few rounds, guarded against recasting while already active - see "The Garrison Ward" above).
10. Optional fields from the Flankers fight: `taunts_all_attacks` (forces every single-target action onto this enemy while it's alive), `fire_spell_chance`/`fire_damage_bonus_percent` (a third offensive spell option alongside ice/poison - bonus damage, no status effect), and `heals_allies_every_turns`/`heal_allies_percent` (heals its most-injured living ally on a fixed schedule instead of attacking). See "The Flankers, and three new group-fight mechanics" above for the shipped example of all three.
11. Optional fields from the East Checkpoint fight: `counters_damage_percent` (reflects a fraction of any hit taken back at whoever landed it), `gambler_blast_chance` (fully random damage, 0 up to twice its own Intelligence - a genuine miss is possible), `lucky_shot_chance`/`lucky_shot_bonus_percent` (its basic attack has a chance to immediately strike again), and `wards_allies_chance` (casts a re-appliable, no-expiry shield on one living ally instead of attacking). See "The East Checkpoint, recruiting the Flankers, and Snake Slaying" above for the shipped example of all four.
12. Optional fields from the Snake miniboss: `aoe_slam_chance`/`aoe_slam_damage_multiplier` (hits every living player-side combatant at once) and `stuns_at_health_percent` (a one-time party-wide stun once health drops to/below this fraction, same one-time-guard shape as the enrage phase). See the same section above.

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

### Reader-paced dialogue, defeat feedback in multi-enemy fights, a real trade confirm, and a nicer abilities menu

**Notifications are no longer timer-based.** `ExplorationHUD.show_notification()` used to show text for a fixed 2.6s then fade it - long text (like the Traveling Adventurer's Wassim pitch) could scroll past before it was readable. It now works like the existing `LoreIntro`/`CityGuardArrival` cinematics: showing a notification pauses the tree (same mechanism `PauseMenu`/`InventoryScreen`/`DialogueChoicePopup` already use) and waits for the player to press Space/Enter (`ui_advance`) or click anywhere, via a new full-screen `NotificationAdvanceArea` button. A message can also be split into several shorter screens by putting `ExplorationHUD.NOTIFICATION_PAGE_BREAK` (`"||"`) between them - `show_notification()` splits on it and queues each page, only unpausing once the queue's empty. The Traveling Adventurer's long Wassim-quest accept text (Plaza.tscn) is the first to use this, split into two natural pages instead of one dense block. This is a blanket change - every `MESSAGE` interactable, item pickup, quest accept/decline line, and trade result across the whole game now reads at the player's own pace instead of a fixed timer.

**Trading now confirms before it charges you.** `ExplorationArea._handle_trade()` used to buy instantly on interact - no way to check a price and walk away. It now shows a Yes/No `DialogueChoicePopup` ("Item Name - N gold. Buy it?") via a new `_compute_trade_price()`/`_on_trade_confirmed()` split (the same Thorned Coin multiplier and Lounge rank-discount logic, just computed once for display and reused for the actual charge) - declining or clicking away costs nothing, matching how every other prompt in the game already works. `GuildLounge.tscn` and `TwoWayAlley.tscn` needed a `DialoguePopup` node added since they'd never needed one before (their only interactables were `TRADE`/`MESSAGE`).

**Defeated enemies now visibly stay defeated.** In a multi-enemy fight, `CombatScene._spawn_enemy_visuals()` only ever ran once at the start of combat (or on a `roster_changed` enrage summon) - an individual enemy dying mid-fight silently vanished from the target list but its battlefield sprite just kept rendering at full opacity forever, indistinguishable from a still-living enemy. `CombatManager` now emits a new `enemy_visual_defeated(enemy)` signal from `_on_enemy_defeated()`; `CombatScene` looks up that unit's index in `enemy_units` (a stable 1:1 mapping with `enemy_container`'s children all combat long) and calls a new `EnemyCharacter.mark_defeated()` - fades and grays the visual and appends "(Defeated)" to its name label, leaving every other combatant untouched.

**The abilities menu is now a proper card list instead of a button-plus-label stack.** `CombatHUD._build_ability_card()` renders each ability as a self-contained clickable `PanelContainer` - a left accent bar and cost-badge color keyed off `AbilityDefinition.AbilityType` (red=Attack, green=Heal, blue=Buff, gold=Defend, purple=Utility), name and resource cost on one row, description below, the whole card dimmed and non-interactive (no click handler even wired up) when unaffordable. Colors come from the ability's *type*, not its id, so any future ability/spell a class picks up automatically gets themed correctly with zero new styling code.

**The City Guard from the opening Back Alley story beat is now tied into the wider Garrison Ward plot.** `resources/lore/city_guard_farewell.tres` gained two closing sections: she's part of the same Southside garrison redeployment referenced by the Knight/Mercenary dialogue in `GarrisonWard.tscn` - she was nearly gone already, and got lucky enough to still be on her beat when the alley fight broke out.

### A pause-related bug class, root-caused and fixed in two places

Reported as "the coin stealer waits until you move" and "a black screen two rooms down that I had to wait out": both traced back to the same root cause introduced by the reader-paced notification change above. Showing a notification pauses the tree - anything that isn't `PROCESS_MODE_ALWAYS` freezes with it, and anything with an in-flight `Tween` freezes mid-animation unless that tween is explicitly told not to care.

- **`SceneManager.goto_scene()`'s fade tween now survives a pause.** `UndergroundNerax`'s first-visit notification fires from `_ready()`, synchronously, while the scene-transition fade-in tween that just loaded it is still mid-sequence. A plain `Tween` respects the tree's pause state by default, so the fade-to-visible step never ran - the fade rect stayed stuck fully opaque (a black screen), and since the SAME pause was also hiding the notification underneath it (drawn on a lower `CanvasLayer` than the fade rect's `layer = 100`), there was no visible prompt telling the player they needed to press Space to free it. Fixed with `tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)` plus a defensive `get_tree().paused = false` at the top of `goto_scene()`, so no future scene transition can get stuck this way regardless of what triggers it.
- **`RushingEnemy` is now `PROCESS_MODE_ALWAYS`.** Its `_physics_process()` drives both detection and the chase - without this, the aggro `rush_notification` (shown the instant it spots the player) paused the tree and froze the chase along with everything else, so the enemy would appear to "wait" motionlessly until the player happened to dismiss a message that gave no visual indication anything needed dismissing. This fix is general (it's on the shared `RushingEnemy.gd`, not any one instance) and covers every current and future rushing-enemy encounter - verified against Garrison Ward's Masked Assassin, the only one left after the change below.
- **The Deep Alley robber ("the coin stealer") is no longer a `RushingEnemy` at all.** Per the report, he's now a guaranteed on-arrival ambush instead of a live chase: `DeeperAlley.gd._on_area_ready()` shows a two-page notification (`ExplorationHUD.NOTIFICATION_PAGE_BREAK`) and only calls `SceneManager.start_combat()` once the new `ExplorationHUD.notification_finished` signal confirms the player actually finished reading it - no detection radius, no pathing, no way for the trigger itself to misfire. The existing "always on first visit, 20% chance on return visits, gone for good once actually defeated" logic is unchanged.

### Five new common-rarity artifacts, a real trade confirm, and Thorned Coin reworked into a usable relic

The artifact pool had zero `COMMON`-rarity entries - everything was Uncommon or higher. Five new ones (**Worn Bracer** +Attack, **Tattered Cloak** +Defense, **Quicksilver Charm** +Speed, **Apprentice's Focus** +Intelligence, **Traveler's Charm** +Health) fill that gap, all sharing one new reusable effect class, `FlatStatBonusEffect` (`effect_values = {"stat": ..., "amount": ...}`) instead of five near-identical scripts - a new basic stat artifact from here on is a `.tres` file, not a new class.

**Selling is no longer an opt-in allowlist.** `ExplorationArea._try_sell_to_vendor()` used to only recognize a handful of items with `ItemDefinition.sell_price` explicitly set (the trophy items). It now treats every droppable item as sellable somewhere, for a base price (`sell_price` if set, otherwise the item's plain `value`) - equipped gear is explicitly excluded (checked against `RunData.equipped.values()`) so interacting with a vendor can never quietly sell your only weapon. Vendors can also name a specialty via two new `Interactable` fields, `sell_bonus_item_ids`/`sell_bonus_multiplier`: if the player is holding one of a vendor's named items, that's what sells (a premium price, priority over anything else in the pack). Wired up on three vendors as examples - the Underground Trader pays extra for trophies/curios, the Market Vendor for consumables, the Guild Lounge's Keeper for weapons.

**Thorned Coin is no longer a passive shop-price/gold-bonus artifact - it's usable.** A new general mechanic: `ArtifactDefinition.usable` + `ArtifactEffectBase.on_manually_used()` + `RunManager.use_artifact()` (once per run, tracked via `RunData.story_flags` like every other one-shot run event) lets an artifact be manually triggered instead of firing off a combat hook. Thorned Coin's effect now just grants a flat burst of gold on use. Triggered from a new **Use** button on InventoryScreen's Artifacts tab, enabled only for `usable` artifacts not yet spent this run.

### A placeholder background for every cutscene, ready for real art later

`LoreIntro`, `CityGuardArrival`, `CityGuardFarewell` and `MaskedManEncounter` all used a flat black `ColorRect` behind their text. They now instance a new reusable `scenes/ui/CutsceneBackground.tscn` instead - a procedural gradient sky (`GradientTexture2D`, no external image needed) plus a simple skyline silhouette, dimmed slightly so text stays readable. `LoreScript` gained a `background_texture` field: leave it unset and the placeholder shows, set it later once real art exists and `CutsceneBackground.set_texture()` swaps it in automatically - the same "texture overrides placeholder" convention `EnemyDefinition`/`AppearanceOption` already use, so dropping in finished art means editing one field per lore resource, not touching any scene or script.

### Combat now returns you to exactly where you stood, and cutscenes cut cleanly instead of flashing to black

**"Return to the exploration scene after combat" used to mean the scene's single authored default `Player` position, or - via `_apply_arrival_spawn()` - whichever `EXIT` node happened to match where the player arrived from,** neither of which has anything to do with where the fight actually started. Every combat trigger now routes through a new `ExplorationArea.start_combat()` (wrapping `SceneManager.start_combat()`, not replacing it) that records the player's exact position into `SceneManager.pending_combat_return_position` the instant the fight begins; `_apply_arrival_spawn()` checks that first, ahead of the `EXIT`-matching fallback, and always wins when it's set. Cleared defensively in `RunManager.start_new_run()` too, so a defeat (which skips straight to the Run Summary instead of back through an exploration scene) can never leak a stale position into a later run.

**Cutscenes (`LoreIntro`, `CityGuardArrival`/`Farewell`, `MaskedManEncounter`) now cut directly to the next scene the moment their text ends, with no fade.** `SceneManager.goto_scene()` gained an `instant` parameter (and `start_combat()` forwards one too, for `CityGuardArrival`'s combat handoff) that skips the fade-to-black tween entirely. This existed to fix a visible black flash that only became noticeable once cutscenes got a real (non-black) placeholder background - fading through solid black between a colorful scene and the next now stood out where it used to be a near-invisible black-to-black cut. Implementing the instant path surfaced a second, real bug: calling `change_scene_to_file()` directly and synchronously (rather than inside the fade tween's callback, which was incidentally always safe) crashes with "Parent node is busy adding/removing children" whenever `goto_scene()` fires from inside a signal callback - which is exactly how every cutscene's `_finish()` is invoked (a button press or `_unhandled_input`). Fixed by routing the instant path through `call_deferred()` like the engine expects, same as the non-instant path's tween callback was already doing implicitly.

### First real artwork: alley_rat, rat_boss, alley_robber, forest_bear

Four `EnemyDefinition.texture` fields are now set to real illustrations dropped into `resources/enemies/` (`Rat.png`, `Rat_Boss.png`, `Alley Robber.png`, `Forest_bear.png`), replacing their placeholder polygons everywhere they appear - exploration map icons, combat visuals, and the turn-order wheel all read from the same `texture` field, so nothing beyond the resource edit was needed.

Source art varies wildly in resolution (1024x1536 up to 1254x1254) and would have rendered at wildly different, mostly-enormous sizes without normalization - a Sprite2D has no built-in "fit to a reasonable size" behavior, it just draws the texture at its native pixel dimensions. `EnemyCharacter._apply_visual()` now scales any texture to a fixed `SPRITE_TARGET_HEIGHT` (64px), aspect ratio preserved, computed from the source image's actual height rather than a hardcoded assumption - so the next piece of art, whatever resolution it comes in at, will match the existing four without any manual per-enemy scale tuning. Verified visually (real, non-headless screenshots) in both an exploration scene (the bear/rat map icons) and would apply identically in combat, since both paths call the same `EnemyCharacter.setup()`.

### More stat-based relics, and a lower drop rate

Six new common/uncommon `FlatStatBonusEffect` artifacts (`champions_gauntlet` +Attack, `bulwark_plate` +Defense, `windrunner_sash` +Speed, `sages_circlet` +Intelligence, `vitality_idol` +max Health, `runed_reservoir` +max Resource - the first artifact to touch the resource pool stat at all) sit a tier above the original five common ones, giving stat-focused loot more room to progress. Artifacts feeling rarer was also the point of the original 35%→20% drop-chance tuning (see "Artifact drop tuning" above); it's now **20%→15%**, `CombatManager._grant_rewards()`.

### The Upper Ward, a beggar's gift, and the inner wall

Southside continues past the Market: a second gap in its south wall (alongside the Plaza exit), "Ward Stairs," leads up into `scenes/world/NeraxUpperWard.tscn`, a quieter street above the market stalls where three beggars shelter against the wall. Two are flavor-only - `NeraxUpperWard.gd._ask_for_coin()` handles their "spare a coin" prompt and thank-you line, no mechanical effect either way. The third, a retired adventurer, is more than he looks: giving him the same 10 gold (once - guarded by `story_flags["old_soldier_gifted"]`, same one-shot-reward convention as every other gift/sale interaction in the game) triggers a short reveal and hands over his own old artifact, **Swiftie Boots**.

**Swiftie Boots introduces a new combat mechanic: an escape option, not just a stat.** Its passive is a small, ordinary +1 Speed (`flat_stat_bonus`, same as any other stat relic), but holding it also unlocks `CombatManager.player_can_flee()` - true only on the player's own turn, only while strictly faster (`get_effective_speed()`, so a haste/freeze debuff counts) than *every* living enemy in the fight, mirroring how the dodge and damage formulas never let the weaker side "win." `CombatHUD` shows a **Run** button only when that's true; using it (`player_attempt_flee()`) ends combat as a clean escape - current health/resource still carries over, same as any other combat exit, but no loot, no experience, and no random-artifact roll, and the encounter slot isn't advanced. This reuses the existing `combat_finished(victory: bool)` signal rather than adding a third outcome type: `_finish_combat()` gained a `fled` parameter that skips `_grant_rewards()`, and `last_rewards["player_fled"]` tells `CombatHUD`/`_on_result_confirmed()` to show a "Got Away!" result and route home without touching `SceneManager.advances_encounter_on_victory`.

Further up from the Upper Ward (north exit) is `scenes/world/InnerWallSouth.tscn` - a guarded checkpoint at the base of Nerax's actual inner wall, distinct from the outer city's low brick. Two guards flank the gate, which is a normal rank-gated `EXIT` (`required_guild_rank_order` = B-Rank's `order`, 4) plus one new, fully generic field: `Interactable.toll_gold_amount`. When a rank-gated `EXIT` is blocked and `toll_gold_amount > 0`, `ExplorationArea._offer_toll()` now shows a Yes/No prompt to pay that much gold and pass anyway instead of just refusing outright - the inner wall gate asks 100 gold, paid fresh every time (no flag set, unlike a one-shot reward). Declining leaves the player exactly where a normal locked door would.

**Past the gate, `scenes/world/InnerNerax.tscn` is a real market square**, not a stub - four vendors around a central fountain, each selling a new `CONSUMABLE`-only item unavailable anywhere in the outer city (no equipment, no stat-modifying gear, matching the district's "residents and escorted business" framing): the Apothecary's **Sunfruit Tonic** (30 health, double a Minor Healing Potion), the Alchemist's **Honeyed Draught** (30 resource), the Wine Merchant's **Spiced Wine** (15 health *and* 15 resource - the first item to restore both at once), and a Street Vendor's cheap **Candied Nuts** (10 health, 4 gold) for anyone who spent their gold getting past the gate. Two more Inner Guards patrol the square itself (flavor `MESSAGE`s, distinct from the checkpoint pair at the gate). Every vendor is a plain `TRADE` interactable reusing the exact same buy-confirmation flow as anywhere else in the game - the only genuinely new content is the four `ItemDefinition` resources themselves.

**The fountain is a real four-way hub, not just scenery.** South is the gate back to `InnerWallSouth`. West and east are both dead-end flavor stubs (a shuttered residential lane, a row of locked-up stalls), reserved for later. North is the way onward, and it's a real `EXIT` this time - `InnerNerax.gd` overrides `_on_interactable_triggered()` for it (same pattern `NeraxOutskirts.gd` already uses for the masked-man portal) to check `story_flags["guards_rush_seen"]`: unset, it plays a one-time cinematic first; set, it goes straight through.

**Two new one-time cinematics bookend the shopping street**, both built from the exact same minimal template `CityGuardFarewell.gd` already established (a `LoreScript`'s `sections` shown one at a time, click/Space/Enter or Skip to advance, `instant = true` on the handoff so the cut lands clean): `GuardsRushCutscene.tscn` (first push north from the fountain - a column of soldiers at a hard march, an officer shouting them toward the Royal Castle over "a situation") and `CentralWallSmokeCutscene.tscn` (first push north from the shops - more guards still rushing the gate ahead, and a thin column of smoke on the horizon nobody comments on because they've clearly already seen it). Each sets its own story flag in `_ready()` and hands off to the next scene; the flag is what lets `InnerNerax.gd`/`InnerNeraxShops.gd` skip straight past the cinematic on every visit after the first.

**The shopping street (`scenes/world/InnerNeraxShops.tscn`) has four shopfronts**, each the `GuildHallDoor`-style facade-plus-`EXIT`-door pattern Plaza already uses for the Adventure Centrum (a decorative building facade, no collision, with a circular-shape `EXIT` interactable in front of it) rather than a wall gap - leading to four distinct, small interior scenes. Every shop has 1-4 ambient flavor NPCs (plain `MESSAGE`s with no story relevance - regulars, apprentices, browsers) alongside its actual vendor stalls, so each interior feels inhabited rather than just a shelf of `TRADE` nodes. The street itself continues north too, past the shops, to `scenes/world/CentralNeraxWard.tscn` - the checkpoint at Central Nerax's own wall, where the highborn and royals live. More guards than anywhere else in the city, all visibly in a hurry, and the smoke from the cinematic now visible over the wall itself; the Senior Guard's "district's on lockdown" line is the in-fiction reason it's a dead end for now, same "real, reachable, not built out yet" convention as `UndergroundNerax` originally was.

- **The Fatted Cleaver** (Butcher) sells four cuts of meat - Cured Ham, Roast Mutton, Prime Beef Cut, Wild Boar Ribs - each a different flat heal amount (12/22/35/55) at a matching price. All four introduce `ItemDefinition.combat_usable` (default `true`): set `false` here, it means "Inventory-screen only" - `CombatManager.player_use_item()` now rejects a non-combat-usable item outright, and `CombatHUD._open_items()` filters it out of the in-fight list entirely, so the meat never even appears as an option mid-fight. Any future item (or existing one) can opt into the same restriction with zero new code.
- **The Gilded Retort** (Alchemist Shop) sells the usual Minor Healing/Mana Potions at an inner-market markup (10 gold each, repeatable, same as any vendor), plus five one-of-a-kind elixirs - **Might** (Attack), **Warding** (Defense), **Swiftness** (Speed), **Insight** (Intelligence) and **Vitality** (HP) - each permanently +3 to its one stat, 150 gold, and each only ever purchasable once. That "only once, per bottle" is a new generic mechanic: `Interactable.purchase_flag_id` (distinct from `story_flag_id`, which fires the instant an interactable is *triggered* - wrong for gating a purchase, since opening the buy prompt and declining or being short on gold would wrongly burn it). `ExplorationArea._handle_trade()` now checks the flag *before* showing the buy prompt, and only sets it in `_on_trade_confirmed()` after the gold is actually spent - genuinely gated on a successful sale, not just an interaction, and each elixir tracks its own flag independently. Consuming one (Inventory screen only - every elixir is `combat_usable = false` too) calls the new `RunManager.grant_stat_bonus(stat_name, amount)`, which bumps that one entry in `run.allocated_stats` directly, bypassing the normal unspent-points gate `allocate_stat_point()` enforces - appropriate for a rare one-off reward rather than the regular level-up flow.
- **Silks & Seams** (Clothing Shop) lets the Tailor restyle the player's appearance for 30 gold - not a new UI, but `CharacterCreator` itself reused in a new "edit mode": `SceneManager.start_appearance_edit(return_scene)` sets `pending_appearance_return_scene` and opens `CharacterCreator`, which checks that var in `_ready()` to lock `NameEdit` (`editable = false` - the name itself can't change) and route Save/Back back to the shop instead of the Main Menu. `ClothingShop.gd` overrides `_on_interactable_triggered()` for the Tailor specifically (same override pattern as the Upper Ward's beggars) to run the Yes/No gold-confirm before handing off.
- **The Curious Case** (Relic Shop / general store) sells five basic gear pieces (Worn Sword, Wooden Shield, Torn Leather Armor, Basic Dagger, Short Bow) that were previously only ever reachable as `starting_equipment` and never purchasable anywhere - plus two new artifacts, **Ironclad Signet** (+8 Defense) and **Phantom Step Charm** (+8 Speed), both `random_drop_eligible = false` like every other exclusive-source relic, so the only way to ever hold one is to pay 200 gold for it here.

### The Flankers, and three new group-fight mechanics

The Plaza's west wall now carries a second exit alongside the existing Two-Way Alley door (`WallLeftBottom` split the same way every other multi-gap wall in the game already is) into `scenes/world/MercenaryCamp.tscn` - an old campsite still within sight of the outer wall to the south (`SouthCityWallBacking`, the same decorative-backdrop trick `InnerWallSouth`/`CentralNeraxWard` already use). Three mercenaries - **the Flankers** - are camped here between jobs. Talking to them (one `Interactable` covering all three, `MercenaryCamp.gd` overriding `_on_interactable_triggered()` the same way the Upper Ward's beggars and the Clothing Shop's Tailor do) is a three-way Yes/No/decline prompt: **Yes** is honest that there's nothing to offer them yet - no work-assignment system exists for them to plug into (that's future content, meant to live wherever a job-giver eventually appears - east of the Plaza, out in the world, or up in the Royal Castle); **No** gets a line about them resting up after a big job and wanting to stay in the loop for the next one; **"Mind your own business"** starts a fight against all three at once, sequenced through `ExplorationHUD.notification_finished` (same pattern `DeeperAlley`'s ambush uses) so combat only starts once the player's actually read the warning line. Winning is guarded by `on_defeat_story_flag_id = "flankers_defeated"` set on all three enemies (redundant-safe - `RunData.story_flags` is just a dict, so it doesn't matter which of the three happens to die last) and drops a new artifact, **Flanker's Signet** (+2 Defense, +2 Speed, +4 Intelligence, `random_drop_eligible = false`, a new bespoke `FlankersSignetEffect` alongside `HeartOfTheHollowEffect` as the game's other multi-stat combo artifact).

The fight itself introduces three new, fully generic `EnemyDefinition` mechanics, one per Flanker:

- **Taunt** (`flanker_tank`, `EnemyDefinition.taunts_all_attacks`). While a taunting enemy is alive, `CombatManager.get_current_target()`/`set_target()` force every single-target action - player basic attack, player `ATTACK`-type ability, ally auto-attack - onto it; `CombatHUD._refresh_enemy_target_list()` disables the other target buttons too so the UI doesn't lie about what clicking them would do. This is explicitly scoped to the single-target resolution path, and the doc comment on the field spells out why that's enough: a future AOE ability (`AbilityDefinition.target_type == ALL_ENEMIES`, already an enum value per the Known Limitations note below, just not wired up yet) would hit every enemy directly via `get_alive_enemies()` rather than calling `get_current_target()` at all, so it bypasses taunt automatically the moment AOE resolution exists - no taunt-side change needed later, which is the whole point of adding the distinction now instead of after the fact.
- **Fire spell** (`flanker_mage`, `EnemyDefinition.fire_spell_chance`/`fire_damage_bonus_percent`). A third offensive option alongside the existing ice spell (damage + chance to slow) and poison attack (damage + residual DOT) - `_perform_fire_spell()` mirrors their shape exactly, just trading the status effect for straight bonus damage. All three chances are checked independently and in sequence in `_enemy_take_single_action()` (poison, then ice, then fire, then a normal attack as fallback), which is what gives the mage her "which spell this turn" variety without needing an actual weighted-random spell-select system.
- **Ally healing** (`flanker_healer`, `EnemyDefinition.heals_allies_every_turns`/`heal_allies_percent`). Every Nth of its own actions (a fixed schedule, not a chance roll - `enemy.actions_taken % N == 0`), it heals whichever living ally (itself included) is missing the most health instead of attacking. Distinct from the existing minion-summon mechanic, which only revives a *dead* teammate - this is the first mechanic that helps an ally that's still standing.

### The East Checkpoint, recruiting the Flankers, and Snake Slaying

**The Plaza's east wall gets the same second-gap treatment as its west wall** (`WallRightBottom` split the same way `WallLeftBottom` was) into `scenes/world/EastCheckpoint.tscn`. The first visit plays a one-time witnessed-injustice notification (a citizen shoved down, a mercenary's "being poor and stubborn is a choice - don't let it be your last one"), then the checkpoint itself - four mercenaries, one `Interactable` covering the group - delivers an ultimatum: hand over every item and artifact, or turn back. **Yes** clears `RunData.inventory`/`equipped`/`artifacts` outright and throws the player into the fight stripped bare anyway (they were never letting anyone through) - a real, chosen risk. **No** retreats with nothing lost and starts a new quest, **Unlock the East Side**; returning to the checkpoint with it active skips the ultimatum and just offers to fight (optionally with the Flankers, if recruited - see below). Either path sets the same `on_defeat_story_flag_id = "east_mercenaries_defeated"` on all four enemies, and `EastCheckpoint._check_east_side_unlock()` (the same "return here implies it happened" convention `GarrisonWard`/`UndergroundNerax` already use) resolves the reward exactly once regardless of which route got there: +1 to *every* core stat, permanent. That reward shape doesn't fit `QuestDefinition`'s reward fields (which grant free points, not a guaranteed spread across all five) - so rather than stretch that system to fit one quest, it's granted directly via a loop over `RunManager.grant_stat_bonus()`, the same low-level primitive the inner market's elixirs already use. Clearing the checkpoint also opens its own east exit into `scenes/world/EasternRoad.tscn`, another deliberately minimal "not built out yet" stub.

**The East Checkpoint fight introduces four more new, fully generic `EnemyDefinition` mechanics, one per mercenary:**

- **Counter** (`checkpoint_brute`, `EnemyDefinition.counters_damage_percent`). The instant a hit lands on him - player or ally - he reflects a fraction of that damage straight back at whoever landed it (`CombatManager._apply_counter()`, always at least 1, ignores defense entirely since it's a reaction rather than a spell). Called right alongside `_check_enrage()`/`_check_piercing_eyes()` at every place a unit takes damage from an attack.
- **Gambler blast** (`checkpoint_gambler`, `EnemyDefinition.gambler_blast_chance`). Fully random damage each cast, from a genuine whiff (0) up to twice her own Intelligence - the only spell in the game where a complete miss is possible. That required a small carve-out: `CombatUnitState.apply_damage()` floors every other hit at 1, so a 0 roll here bypasses `apply_damage()` entirely instead of being rounded up to a "guaranteed" 1.
- **Lucky Shot** (`checkpoint_marksman`, `EnemyDefinition.lucky_shot_chance`/`lucky_shot_bonus_percent`). A flat chance for his ordinary basic attack to immediately strike again for a fraction of the first hit's damage - folded directly into the normal-attack branch of `_enemy_take_single_action()`, not a separate spell option.
- **Ward** (`checkpoint_defender`, `EnemyDefinition.wards_allies_chance`). Casts a shield on one living, not-yet-shielded ally (himself included) that blocks the next hit that lands on them completely, with no expiry of its own - it just sits there until consumed. This is `CombatUnitState.shielded`, a manually re-appliable sibling to the older one-time-per-combat `has_absorbed_hit`/`absorbs_first_hit` pair; `_rolls_shield()` now checks both, the manual ward first since it has no "once per combat" limit to fall back past.

**Recruiting the Flankers finally gives their original "sorry, nothing for now" placeholder somewhere to plug into.** Back at the campsite, if `unlock_east_side` or the new guild quest `snake_slaying` (below) is active and the Flankers haven't been recruited for it yet, `MercenaryCamp.gd` offers to bring them along instead of the original pitch. Recruiting doesn't move them anywhere - it just sets a `flankers_recruited_for_<mission>` flag that the relevant scene reads when it starts that one fight, passing their ids as `ally_ids` into the existing `start_combat()`/`CombatManager.start()` ally support. They're a one-time resource either way: the next time the player is back at camp after that mission fight has actually concluded (checked via that mission's own completion flag, so wandering back mid-quest doesn't resolve anything early), `MercenaryCamp._check_flanker_retirement()` reads a new `RunData.last_combat_ally_casualty_ids` (populated by `CombatManager._finish_combat()` whenever a fight had allies present, independent of who those allies were) - if any of the three died, the survivors retire and gift **Flanker's Signet** on the way out; if all three made it through, they just thank the player and move on with nothing given. Either way they're hidden for good afterward. This needed one new data type: `AllyDefinition` resources for the three Flankers (`resources/allies/flanker_*.tres`), completely separate from their `EnemyDefinition` counterparts of the same id (different registries, same identity) - as allies they're plain auto-attackers like any other recruited NPC, none of their enemy-side spells/taunt/counter carry over, matching the "no manual ally control, no special ally abilities" scope the rest of the ally system already has.

**Snake Slaying** is a new B-Rank-gated guild mission (`resources/quests/snake_slaying.tres`, offered by a new Guild Officer NPC in the Adventure Centrum - `required_guild_rank_order`/`locked_message` on a plain `DIALOGUE` interactable, zero new script code needed, same mechanism `Blade in the Dark`/`Find Wassim` already use): a snake has killed a fellow adventuring party and is closing in on the city. It's a kill-count quest (`objective_enemy_id = "forest_snake"`, count 1) so it auto-completes the instant the snake dies, through the same infrastructure `Kill the Bees`/`Wolf Cull` already use - no custom completion code needed there either. The snake itself (`DeepForest.tscn`, gated behind the quest being active via `DeepForest.gd._approach_snake()` - otherwise just an ominous flavor line, so nobody stumbles into a level-9 miniboss before the guild's even mentioned it) is a real miniboss with two more new mechanics and a guaranteed artifact:

- **AOE slam** (`EnemyDefinition.aoe_slam_chance`/`aoe_slam_damage_multiplier`). Hits every living player-side combatant at once - `CombatManager._perform_aoe_slam()` loops `_get_alive_party_members()` and resolves each hit against that target's own defense independently, rather than one shared roll.
- **Piercing Eyes** (`EnemyDefinition.stuns_at_health_percent`). A one-time party-wide stun the instant health drops to/below the threshold - same one-time-guard shape as the existing enrage phase, checked at the same call sites. The stun itself is new, generic status state: `CombatUnitState.stun_turns_remaining`, checked in `_advance_round_action()` right after poison ticks. A stunned unit's turn still visibly happens (`turn_changed` still fires, and poison above it in the same function still ticks) but the action itself - the input prompt for the player, the AI step for an ally/enemy - is skipped outright and the round moves straight on.
- **Serpent's Fang** (guaranteed on defeat, `random_drop_eligible = false`): heals the player for 10% of every hit they land. This needed a genuinely new hook, since the existing `on_player_attacked` fires *before* the defense/crit math resolves (it's there for artifacts that want to modify the hit, like Cinder Ring) and doesn't carry the real final number. `EventBus.player_dealt_damage` is the post-resolution counterpart - emitted once `_perform_player_attack()` knows the actual amount dealt - with a matching `ArtifactEffectBase.on_player_dealt_damage()` hook and `ArtifactSystem` binding, ready for any future artifact that wants to react to a completed hit rather than change it.

### A proper trader screen

**Selling used to be genuinely unclear.** Interacting with any `TRADE`-kind vendor ran `ExplorationArea._try_sell_to_vendor()` first, which - silently, with no prompt - sold the first sellable item found in the player's pack, and only offered to buy the vendor's own stock item if there was nothing left to sell that turn. There was no way to see what was about to be sold, no way to choose which item, and buying could be blocked by a sale you never asked for.

That whole flow is gone, replaced by `scenes/ui/TraderScreen.tscn` - a proper two-tab panel (**Buy** / **Sell**), opened for every `TRADE` interactable in the game. The Buy tab shows the vendor's stock item, its price (rank-discount and purchase-flag gating both still computed the same way, now via a public `ExplorationArea.compute_trade_price()`), and a Buy button. The Sell tab lists *every* sellable item currently in the pack - name, quantity, price (a vendor's named specialty, `sell_bonus_item_ids`/`sell_bonus_multiplier`, is reflected per-row) - each with its own Sell button, plus a **Sell All** button that clears the whole list in one pass and reports the total gold earned. `ExplorationArea._handle_trade()` now just opens the shared screen and pauses the tree, same as `InventoryScreen`.

The screen itself is instantiated once per exploration area at runtime (`ExplorationArea._ready()` preloads and adds it as a child of the same `CanvasLayer` `HUD` already lives under) rather than being added to every scene's `.tscn` individually - one shared trader UI works for every vendor in the game with zero per-scene setup, the same way `TraderScreen.open(self, interactable)` just needs the `Interactable` being talked to and a reference back to the area for its `hud`/pricing helpers.

## Known limitations & suggested next steps

This is an MVP: the systems are real and reusable, but scope was intentionally kept small.

- **Mostly placeholder visuals.** Four enemies now have real art (`alley_rat`, `rat_boss`, `alley_robber`, `forest_bear` - see below); everything else is still a solid-color polygon. The layered appearance system and `AppearanceOption.texture` / `EnemyDefinition` fields are ready to accept real art for the rest without restructuring.
- **No manual ally control.** Allies (see "Targeting & allies" above) are always AI-controlled - they auto-attack whatever the player has targeted. Giving the player direct control over an ally's actions would be the natural next step if a future ally needs to do more than basic-attack.
- **No ability/item targeting beyond the current enemy target.** Every player and ally action goes through `CombatManager.get_current_target()`; there's no way to target, say, an ally with a heal, or hit "all enemies" even though `AbilityDefinition.TargetType.ALL_ENEMIES` exists as an enum value - it isn't wired up to any resolution logic yet.
- **Linear encounter sequence**, not a branching dungeon/map. `EncounterRegistry` already separates "what kinds of encounters exist" from "how the sequence is generated," so swapping in a graph/room-based generator later doesn't require touching the encounter resources.
- **No audio.** `AudioManager` and the settings UI are wired up; no sound assets are included.
- **Quests have no in-progress tracking beyond the pause menu list**, no quest markers/waypoints, and completion is currently always "arrive somewhere" or "talk to someone" - there's no generic "kill N enemies" or "collect N items" objective type yet, though `RunManager.complete_quest()` doesn't care *how* a quest gets marked active/complete, so adding one is mostly about calling `start_quest()`/`complete_quest()` from the right place.
- **"Guild tax" only discounts quest gold, not combat/encounter currency.** The guild rank system was built against the quest system specifically; extending the same `tax_discount_percent` to enemy `currency_reward`/encounter gold would mean applying it in `CombatManager`/`EncounterScreen` too.
- **B-Rank's "special missions" flag exists but has no content.** `GuildRankDefinition.unlocks_special_missions` is tracked and set correctly on B/A/S, but no quest currently checks it - it's there for a future quest (or a receptionist offer) to gate on.
- **Guild rank never goes down and can't be re-tested at a lower rank** other than starting a new run - there's no mechanic (missed payments, demotion, etc.) that would lower it.
- **No controller/touch input yet.** All input goes through the Input Map actions (`move_*`, `interact`, `pause_menu`, `inventory_toggle`, `ui_advance`), so adding a controller or on-screen touch layer means adding new bindings to those actions, not new code.
- **Basic AI.** Enemy behaviour is a simple probability roll (attack vs. defend) based on `behavior_type`; no positioning, focus-fire, or multi-turn planning.
- **Save migration is scaffolded but untested** - every save resource has a `save_version` field and the loaders already tolerate missing/corrupt files, but no old-format migration path exists yet (`RunData` is currently at v6; nothing reads older data specially, it just falls back to field defaults).
