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
scenes/world/AdventureCentrum.tscn  - guild hall; resolves the Find Wassim quest on arrival
scenes/world/CityGuardArrival.tscn  - story beat: guard arrives, revenge thugs incoming
scenes/world/CityGuardFarewell.tscn - story beat: guard asks where you live, assumes Southside
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

### The Southside map

Exploration is now a small connected map, not a single room:

```
BackAlley (dead end, spawn point)
    <-- one exit -->
TwoWayAlley (junction; has the alley trader)
    <-- one exit -->                    <-- other exit -->
  (back to BackAlley)                 Plaza (Nerax's central plaza; food vendor, swindler, adventurer NPC)
                                           <-- city gate -->        <-- guild hall door -->
                                EncounterScreen (randomized run)   AdventureCentrum (resolves the Find Wassim quest)
```

Every `Interactable` of kind `EXIT` carries its own `exit_target_scene`, so the map graph is just data sitting in each scene file - there's no separate "level graph" resource to keep in sync. Add a new area by making a new `.tscn` + a two-line `ExplorationArea` subclass (see above) and pointing an `EXIT` interactable at it.

### Story beats & the Back Alley Thug scenario

The back alley has a second, one-time combat encounter (in addition to the Alley Rat) that kicks off a short scripted sequence: beating the **Back Alley Thug** interactable there routes (via `Interactable.victory_return_scene`) to `scenes/world/CityGuardArrival.tscn` instead of back into the alley. That scene plays a short LoreIntro-style beat (text in `resources/lore/city_guard_arrival.tres`) - a City Guard of Nerax arrives, and more thugs show up looking for revenge - then starts a second fight (`["back_alley_thug", "back_alley_thug"]`) with the Guard fighting alongside the player as an ally. Winning that routes to `scenes/world/CityGuardFarewell.tscn` (text in `resources/lore/city_guard_farewell.tres`), a short beat where she asks where you live and assumes Southside before you can answer, before finally returning to the Back Alley for good.

This whole sequence only fires once per run: `Interactable.story_flag_id` ("back_alley_thug_defeated" here) is checked/set against `RunData.story_flags` (a generic `flag_id -> bool` bag, persisted with the run) the moment the interactable is triggered, and `ExplorationArea._connect_interactables()` hides/disables any interactable whose flag is already set on future visits. The same `story_flag_id` mechanism is reusable for any future one-shot story beat - it isn't specific to this scenario.

### Trading

Both the Two-Way Alley (the "Back-Alley Trader") and the Plaza (a legitimate Food Vendor, and a "Shifty Peddler" reselling the same potion at a markup) have repeatable `Interactable`s of kind `TRADE` that sell `trade_item_id` for `trade_price` gold - `ExplorationArea._handle_trade()` checks the player has enough `RunData.currency`, then deducts it and adds the item. If the player holds the Thorned Coin artifact, its price is bumped by `ThornedCoinEffect.get_shop_price_multiplier()` - a hook that artifact always defined but that nothing called until these traders existed. An optional `trade_flavor_text` is appended to the purchase notification (the peddler's "extra effects, guaranteed" line is just flavor text - mechanically it sells the exact same `minor_healing_potion` the honest vendors do, just overpriced). Add a new vendor by dropping a `TRADE`-kind `Interactable` anywhere with `trade_item_id`/`trade_price` set.

### Dialogue & quests

The Plaza's "Traveling Adventurer" is an `Interactable` of kind `DIALOGUE`: interacting opens `DialogueChoicePopup` (`scenes/ui/DialogueChoicePopup.tscn`, added once per scene that needs it) with a fixed Yes / No / "Mind your own business" choice. `ExplorationArea._on_dialogue_choice()` shows the matching `dialogue_yes_text`/`dialogue_no_text`/`dialogue_decline_text`, and - only on Yes, and only if `quest_id` is set - starts that quest via `RunManager.start_quest()`. Talking again while the quest is active or after it's done shows `dialogue_quest_active_text`/`dialogue_quest_done_text` instead of repeating the pitch.

Quests are `QuestDefinition` resources (`resources/quests/*.tres`, loaded by `QuestRegistry`) tracked per-run in `RunData.active_quests`/`completed_quests`. `RunManager.complete_quest(quest_id)` grants any combination of `reward_gold`, `reward_exp`, `reward_stat_points`, `reward_item_ids` and a single `reward_artifact_id` - unset fields just grant nothing, so a reward can be as small or as combined as the quest needs. The one shipped example, **Find Wassim**, is completed by simply arriving in `AdventureCentrum.tscn` while it's active (`AdventureCentrum._on_area_ready()` calls `complete_quest()` and shows a resolution notification) - "explore this place" is a valid quest objective without needing any special turn-in NPC or item. Active/completed quests are listed on the pause menu's Character Info screen.

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

### Add an enemy

1. Create a new `EnemyDefinition` resource in `resources/enemies/` (duplicate `resources/enemies/back_alley_thug.tres`).
2. Set `id`, `display_name`, `stats` (a `StatBlock`), `behavior_type` (`AGGRESSIVE` / `DEFENSIVE` / `RANDOM` - controls how often it defends instead of attacking), `loot_table` (array of `{"item_id": ..., "chance": 0.0-1.0}`), `xp_reward`, `currency_reward`, `body_color`, and a `shape_points` placeholder polygon.
3. It's now selectable by `EnemyRegistry.get_random_id()` (used by randomized combat encounters) and can be referenced by id from any `Interactable` with `kind = COMBAT` in an exploration scene.

### Add an artifact

1. **Data:** create a new `ArtifactDefinition` `.tres` in `resources/artifacts/` with `id`, `display_name`, `description`, `rarity`, `icon_color`, `effect_id` (a new string key), `effect_values` (whatever tuning numbers your effect needs), `stacking_allowed`, and optional `class_restrictions`.
2. **Behaviour:** create a new class under `scripts/artifacts/effects/` extending `ArtifactEffectBase`, overriding only the hooks it needs (`on_combat_started`, `on_player_attacked`, `on_enemy_defeated`, `get_passive_stat_modifier`, etc. - see the five existing effects for examples of each pattern).
3. **Wire it up:** add one `"your_effect_id": return YourEffect.new()` line to `ArtifactEffectFactory.create()`.

No existing artifact code needs to change.

### Add an item

Create a new `ItemDefinition` `.tres` in `resources/items/` with `category` (`WEAPON`/`ARMOR`/`CONSUMABLE`/`QUEST`), `rarity`, `icon_color`, `equip_slot` (`"weapon"`, `"offhand"`, `"armor"`, or `""`), `stat_modifiers` (a `StatBlock`, for equipment), and `heal_amount`/`resource_amount` (for consumables). It's immediately available to grant via loot tables, `Interactable` `ITEM` triggers, or a class's `starting_equipment`/`starting_equipped`.

### Add an encounter type or lore/dialogue text

Encounter kinds live in `resources/encounters/` (`EncounterEntry` resources: `kind`, `weight`, `display_name`, `flavor_text`) and are picked by weighted random roll in `EncounterRegistry.generate_sequence()`. Lore and other one-off dialogue text (the intro, the back-alley wake-up notification) live in `resources/lore/` as `LoreScript` resources (`sections: Array[String]`) - edit the array to change the words, no script changes.

## Known limitations & suggested next steps

This is an MVP: the systems are real and reusable, but scope was intentionally kept small.

- **Placeholder visuals only.** Every sprite is a solid-color polygon. The layered appearance system and `AppearanceOption.texture` / `EnemyDefinition` fields are ready to accept real art without restructuring.
- **No manual ally control.** Allies (see "Targeting & allies" above) are always AI-controlled - they auto-attack whatever the player has targeted. Giving the player direct control over an ally's actions would be the natural next step if a future ally needs to do more than basic-attack.
- **No ability/item targeting beyond the current enemy target.** Every player and ally action goes through `CombatManager.get_current_target()`; there's no way to target, say, an ally with a heal, or hit "all enemies" even though `AbilityDefinition.TargetType.ALL_ENEMIES` exists as an enum value - it isn't wired up to any resolution logic yet.
- **Linear encounter sequence**, not a branching dungeon/map. `EncounterRegistry` already separates "what kinds of encounters exist" from "how the sequence is generated," so swapping in a graph/room-based generator later doesn't require touching the encounter resources.
- **No audio.** `AudioManager` and the settings UI are wired up; no sound assets are included.
- **Trading has no dedicated shop UI.** Buying is instant on interact (no browse/confirm screen) - fine for a single-item vendor, but a multi-item shop would want a proper menu.
- **Quests have no in-progress tracking beyond the pause menu list**, no quest markers/waypoints, and completion is currently always "arrive somewhere" or "talk to someone" - there's no generic "kill N enemies" or "collect N items" objective type yet, though `RunManager.complete_quest()` doesn't care *how* a quest gets marked active/complete, so adding one is mostly about calling `start_quest()`/`complete_quest()` from the right place.
- **No controller/touch input yet.** All input goes through the Input Map actions (`move_*`, `interact`, `pause_menu`, `inventory_toggle`, `ui_advance`), so adding a controller or on-screen touch layer means adding new bindings to those actions, not new code.
- **Basic AI.** Enemy behaviour is a simple probability roll (attack vs. defend) based on `behavior_type`; no positioning, focus-fire, or multi-turn planning.
- **Save migration is scaffolded but untested** - every save resource has a `save_version` field and the loaders already tolerate missing/corrupt files, but no old-format migration path exists yet (`RunData` is currently at v2; nothing reads v1 data specially, it just falls back to field defaults).
