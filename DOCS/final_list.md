# MaXtreme — User-Journey Audit & Implementation Roadmap

> **Generated:** 2026-02-06 | **Revised:** 2026-02-08 (Phase 29)
> **Audit method:** Top-down user-journey trace. Every screen and player action in
> the original M.A.X.R. source code is walked through in sequence; the Godot
> implementation is checked at each step.

---

## Phase Progress Overview

| Phase | Name | Status | Items |
|-------|------|--------|-------|
| 18 | Pre-Game Setup Flow | DONE | 10/10 |
| 19 | Core Unit Actions | DONE | 13/13 |
| 20 | In-Game Information & HUD | DONE | 10/10 |
| 21 | Research & Upgrades | DONE | 7/7 |
| 22 | Mining, Resources & Economy | DONE | 6/6 |
| 23 | Notifications & Event Log | DONE | 7/7 |
| 24 | Save/Load System | DONE | 5/5 |
| 25 | Map Overlays & Toggles | DONE | 10/10 |
| 26 | Construction & Building Enhancements | DONE | 7/7 |
| 27 | End-Game | DONE | 8/8 |
| 28 | Reports & Statistics | DONE | 4/4 |
| 29 | Keyboard Shortcuts & UX | DONE | 6/6 |
| **30** | **Preferences & Settings** | **UP NEXT** | **0/6** |
| 31 | Advanced Unit Features | TODO | 0/9 |
| 32 | Multiplayer Enhancements | TODO | 0/10 |
| 33 | Audio & Polish | TODO | 0/5 |

**Completed: 12 phases (93 items) | Remaining: 4 phases (30 items) | Total: 16 phases (123 items)**

---

## Audit Methodology

The previous audit (v1) was **bottom-up** — it scanned C++ class names and checked
whether GDExtension bindings existed. This approach finds individual methods but
misses entire **workflows** (e.g. the multi-step unit purchasing / landing flow
that spans several classes, screens, and data structures).

This revision uses a **top-down user-journey** approach:

1. **Trace every screen** a player sees from launch to game-over.
2. **Trace every action** a player can take on their turn.
3. **Cross-reference against language strings** (`Title~*`, `Comp~*`, `Option~*`)
   — each string corresponds to a visible UI element.
4. **Cross-reference against network messages** — each message type corresponds to
   a player action or lobby event.
5. **Cross-reference against the CHANGELOG** — each entry is a feature that shipped.

Status indicators:

| Tag | Meaning |
|-----|---------|
| **DONE** | Fully working in Godot |
| **PARTIAL** | Some parts work, key functionality incomplete |
| **MISSING** | Feature exists in C++ but has no GDScript UI or wiring |
| **EXPOSED** | C++ method bound in GDExtension but never called from GDScript |
| **STUB** | GDScript code exists but is empty / hardcoded / non-functional |
| **N/A** | Not applicable to Godot remake (e.g. SDL-specific code) |

---

# PART A — USER JOURNEY AUDIT

---

## Journey 1: Main Menu → New Game → Pre-Game → Game Start

> This traces the **complete flow** from launching the game to the first in-game
> turn. The original game has **10 distinct steps** between clicking "New Game" and
> playing. The current Godot build has **3**.

### Screen 1.1 — Main Menu

| Element | Original | Godot | Status |
|---------|----------|-------|--------|
| New Game button | Yes | Yes | **DONE** |
| Hot Seat button | `Title~HotSeat` | Yes | **DONE** |
| Load Game button | `Title~Load` | Button exists, disabled | **STUB** |
| Multiplayer Host button | Yes | Yes (via lobby) | **DONE** |
| Multiplayer Join button | Yes | Yes (via lobby) | **DONE** |
| Preferences / Options | `Title~Options` | — | **MISSING** |
| Credits / About | `Title~Credits`, `data/ABOUT` | — | **MISSING** |
| Show Intro button | CHANGELOG 0.2.11 | — | **MISSING** |
| Quit button | Yes | Yes | **DONE** |

### Screen 1.2 — Lobby / New Game Setup

| Element | Original | Godot | Status |
|---------|----------|-------|--------|
| Map selection | `Title~Map` | Yes (dropdown) | **DONE** |
| Map preview | Yes | Yes (minimap preview) | **DONE** |
| Player name input | `Title~Player_Name` | Yes | **DONE** |
| Player colour picker | `Title~Color` | Yes (dropdown) | **DONE** |
| Player count (up to 8) | `Title~Players` | Yes | **DONE** |
| Game type selection | `Title~Game_Type` (Simultaneous / Turn-Based / Hot Seat) | Yes (dropdown) | **DONE** |
| Victory condition | Death / Turns / Points | Yes (dropdown + spinboxes) | **DONE** |
| Starting credits | `Title~Credits_start` | Yes (spinbox) | **DONE** |
| Bridgehead type | Mobile / Definite | Yes (dropdown) | **DONE** |
| Alien tech toggle | `Title~Alien_Tech` | Yes (checkbox) | **DONE** |
| Resource amounts (Metal/Oil/Gold) | `Title~Metal`, `Title~Oil`, `Title~Gold` | Yes (dropdowns) | **DONE** |
| Resource density | `Title~Resource_Density` | Yes (dropdown) | **DONE** |
| Turn time limit | `Title~Turn_limit` | Yes (spinbox) | **DONE** |
| Turn-end deadline | `Title~Turn_end` | Yes (spinbox) | **DONE** |
| Clan selection per player | `Title~Choose_Clan`, `Title~Clans` | Dropdown exists | **PARTIAL** — no clan stat descriptions |
| Team assignment per player | `Title~Team` | — | **MISSING** |
| Ready state per player | Lobby `MU_MSG_IDENTIFIKATION` | — (single-player only) | **N/A offline** |
| Start Game button | `MU_MSG_ASK_TO_FINISH_LOBBY` | Yes | **DONE** |

### Screen 1.3 — Choose Clan (detail screen)

| Element | Original | Godot | Status |
|---------|----------|-------|--------|
| Clan list with descriptions | `Title~Choose_Clan` | — | **MISSING** |
| Stat modifier table per clan | `cClanUnitStat` modifications (Damage, Range, Armor, HP, Scan, Speed, Build Cost) | — | **MISSING** |
| Clan 7 special rules display | Extra engineers/constructors per credit tier | — | **MISSING** |

### Screen 1.4 — Choose Units (Pre-Game Unit Purchasing)

> **This is the screen the audit missed. It is fundamental to gameplay.**
> Language strings: `Title~Choose_Units`
> C++ flow: `computeInitialLandingUnits()` in `gamepreparation.cpp`

| Element | Original | Godot | Status |
|---------|----------|-------|--------|
| Unit purchase screen | `Title~Choose_Units` | — | **MISSING** |
| Available unit list with icons, names, costs | `getDynamicUnitData()` per clan | — | **MISSING** |
| Add / remove units to landing roster | `sLandingUnit` vector | — | **MISSING** |
| Credit budget display (spent / remaining) | `startCredits` minus unit costs | — | **MISSING** |
| Cargo slider per unit | `sLandingUnit::cargo`, cost = `cargo / 5` | — | **MISSING** |
| Free units for Definite bridgehead | Constructor + Engineer + Surveyor (auto-added) | — | **MISSING** |
| No free units for Mobile bridgehead | Full budget, player buys everything | — | **MISSING** |
| Pre-game upgrade purchasing tab | `sInitPlayerData::unitUpgrades` | — | **MISSING** |
| Hot Seat: sequential per player with transition | Each player shops in turn | — | **MISSING** |
| Multiplayer: simultaneous with server collection | `MU_MSG_START_GAME_PREPARATIONS` | — | **MISSING** |

**What currently happens instead:** `game_setup.cpp` hardcodes 1 Constructor +
2 Tanks + 1 Surveyor for every player, ignoring bridgehead type, clan, and
credits. The player never sees this screen.

### Screen 1.5 — Landing Position Selection

> Language strings: `Title~BridgeHead`, `Comp~Landing_Select`, `Comp~Landing_Too_Close`, `Comp~Landing_Warning`
> C++ classes: `cLandingPositionManager`, `enterLandingSelection()`, `selectLandingPosition()`

| Element | Original | Godot | Status |
|---------|----------|-------|--------|
| Map view for position selection | Full terrain view | — | **MISSING** |
| Click to choose landing position | `selectLandingPosition()` → `MU_MSG_LANDING_POSITION` | — | **MISSING** |
| Validation: must be on land | `isValidLandingPosition()` | — | **MISSING** |
| Warning: too close to another player | `Comp~Landing_Too_Close` | — | **MISSING** |
| Deployment radius preview | Shows where units will land around the chosen point | — | **MISSING** |
| Multiplayer: position exchange & validation | `cLandingPositionManager` orchestrates | — | **MISSING** |
| Hot Seat: sequential with hidden screen | Players choose in turn | — | **MISSING** |

**What currently happens instead:** `game_setup.cpp` calculates evenly-spaced
positions along the horizontal center of the map. Players have no choice.

### Screen 1.6 — Game Initialisation (ActionInitNewGame)

| Element | Original | Godot | Status |
|---------|----------|-------|--------|
| Set player clan | `sInitPlayerData::clan` | — (hardcoded) | **STUB** |
| Validate & set landing position | `cActionInitNewGame::execute()` | — (hardcoded) | **STUB** |
| Apply unit upgrades (deduct credits) | `unitUpgrades` loop | — (skipped) | **MISSING** |
| Place initial resources on map | `placeInitialResources()` | Called | **DONE** |
| Place mining stations (Definite bridgehead) | `placeMiningStations()` | — | **MISSING** |
| Add aliens if enabled | `addAliens()` | Called if `alien_enabled` | **DONE** |
| Land purchased vehicles | `makeLanding()` with purchased units | — (hardcoded units) | **STUB** |
| Transfer remaining credits to player | Credits minus unit costs | — (full credits given) | **STUB** |

---

## Journey 2: In-Game — Player Turn

> Traces everything a player can see and do during their turn.

### 2A — HUD & Information Displays

| Element | Original | Godot | Status |
|---------|----------|-------|--------|
| Resource bar (Metal, Oil, Gold, Energy, Credits) | Top HUD | Yes (Metal/Oil/Gold/Credits) | **PARTIAL** — Energy missing |
| Human resources (workers) display | `getHumanProd()`, `getHumanNeed()` | — | **MISSING** |
| Turn counter | Turn number display | Yes | **DONE** |
| Current player display | Player name + colour | Yes | **DONE** |
| Turn timer / countdown | `cTurnTimeClock` | — | **MISSING** |
| Minimap | Yes | Yes | **DONE** |
| Minimap zoom toggle | `toggleMiniMapZoom` | — | **MISSING** |
| Minimap attack-units-only filter | `miniMapAttackUnitsOnly` | — | **MISSING** |
| Score display (Points victory) | `player.get_score()` | — (exposed, never called) | **EXPOSED** |
| Eco-sphere count | `getNumEcoSpheres()` | — | **MISSING** |

### 2B — Unit Selection & Information

| Element | Original | Godot | Status |
|---------|----------|-------|--------|
| Click to select unit | Yes | Yes | **DONE** |
| Selected unit info panel (basic stats) | Yes | Yes (name, HP, ammo, speed) | **PARTIAL** |
| Full unit status screen | `Title~Unitinfo` — all stats, cargo, stored units | — | **MISSING** |
| Unit experience / rank display | Greenhorn → Grand Master | — | **MISSING** |
| "Dated" unit indicator | Unit stats behind current research level | — | **MISSING** |
| Disabled unit indicator | `unit.is_disabled()`, `get_disabled_turns()` | — (exposed, never called) | **EXPOSED** |
| Box-select multiple units | Shift+drag | — | **MISSING** |
| Shift+click multi-select | Yes | — | **MISSING** |
| Unit groups (Ctrl+1-9 assign, 1-9 recall) | Yes (CHANGELOG 0.2.7) | — | **MISSING** |
| Click unit name to rename | `cActionChangeUnitName` | — (exposed, never called) | **EXPOSED** |

### 2C — Movement

| Element | Original | Godot | Status |
|---------|----------|-------|--------|
| Right-click to move | Yes | Yes | **DONE** |
| Path calculation & preview | `cPathCalculator` | Path shown on click | **DONE** |
| Path preview (Shift+hover) | Shift+Left-Mouse preview (CHANGELOG 0.2.11) | — | **MISSING** |
| Move animation | Yes | Yes (`move_animator.gd`) | **DONE** |
| Group movement | Multiple selected units move together | — | **MISSING** |
| End-move actions (attack/load/enter after move) | `eEndMoveAction` | — | **MISSING** |
| Auto-move (surveyors) | `cActionSetAutoMove`, `cSurveyorAi` | — (exposed, never called) | **EXPOSED** |
| Resume interrupted move | `cActionResumeMove` | — | **MISSING** |
| Vehicle tracks on terrain | `makeTracks` flag | — | **MISSING** |
| Saved camera positions | F5-F8 recall, Alt+F5-F8 save (CHANGELOG 0.2.10) | — | **MISSING** |

### 2D — Combat

| Element | Original | Godot | Status |
|---------|----------|-------|--------|
| Click target to attack | Yes | Yes | **DONE** |
| Attack animation & effects | Yes | Yes (`combat_effects.gd`) | **DONE** |
| Attack range overlay | Yes | Yes (`overlay_renderer.gd`) | **DONE** |
| Reaction fire (sentry auto-attack) | `provokeReactionFire()`, `doReactionFire()` | — | **MISSING** |
| Sentry mode toggle | `cActionChangeSentry` | — (exposed, never called) | **EXPOSED** |
| Manual fire mode toggle | `cActionChangeManualFire` | — (exposed, never called) | **EXPOSED** |
| Drive-and-fire capability | `canDriveAndFire` flag | — | **MISSING** |
| Mine detonation | Mine contact explosion | — | **MISSING** |

### 2E — Construction & Building

| Element | Original | Godot | Status |
|---------|----------|-------|--------|
| Build panel (select building) | `Title~Build_Factory`, `Title~Build_Vehicle` | Yes (`build_panel.gd`) | **DONE** |
| Building placement preview | Yes | Yes | **DONE** |
| Building construction animation | Yes | Basic | **PARTIAL** |
| Resource cost display before placement | Shows cost | — | **MISSING** |
| Build time estimate | Shows turns remaining | — | **MISSING** |
| Cancel construction | Stop mid-build | — | **MISSING** |
| Turbo build (speed multiplier) | `maxBuildFactor` | — | **MISSING** |
| Road/bridge/platform building | `canBuildPath` | — | **MISSING** |
| Bridge/platform rendering | `hasBridgeOrPlatform()` | — | **MISSING** |
| 2x2 (big) building placement | `isBig` flag | — (exposed, never checked) | **EXPOSED** |
| Connector buildings (base network) | `connectsToBase` | — | **MISSING** |

### 2F — Production (Factory Management)

| Element | Original | Godot | Status |
|---------|----------|-------|--------|
| Production panel | Yes | Yes (`production_panel.gd`) | **DONE** |
| Build list editing | `cActionChangeBuildList` | Yes | **DONE** |
| Production start/stop | `cActionStartWork` / `cActionStop` | Yes | **DONE** |
| Production progress display | Yes | Yes | **DONE** |
| Production complete notification | Event report | — | **MISSING** |
| Production blocked notification | Insufficient materials | — | **MISSING** |

### 2G — Research

| Element | Original | Godot | Status |
|---------|----------|-------|--------|
| Research panel / labs menu | `Title~Labs` | — | **MISSING** |
| 8 research areas (Attack, Shots, Range, Armor, HP, Speed, Scan, Cost) | `cResearch` | — (exposed, never called) | **EXPOSED** |
| Allocate research centres to areas | `actions.change_research()` | — (exposed, never called) | **EXPOSED** |
| Research level display per area | `player.get_research_levels()` | — (exposed, never called) | **EXPOSED** |
| Progress / turns remaining | Research centre count × turns | — | **MISSING** |
| Research complete notification | Report type | — | **MISSING** |

### 2H — Upgrades

| Element | Original | Godot | Status |
|---------|----------|-------|--------|
| Upgrades menu (gold purchases) | `Title~Upgrades_Menu` | — | **MISSING** |
| Per-stat upgrades for unit types | `cActionBuyUpgrades` | — (exposed, never called) | **EXPOSED** |
| Vehicle upgrade at depot | `cActionUpgradeVehicle` | — (exposed, never called) | **EXPOSED** |
| Building upgrade | `cActionUpgradeBuilding` | — (exposed, never called) | **EXPOSED** |
| "Upgrade All" buildings of same type | `upgrade_all` parameter | — | **MISSING** |
| Upgrade cost display | Gold cost | — | **MISSING** |

### 2I — Logistics (Load, Transfer, Repair)

| Element | Original | Godot | Status |
|---------|----------|-------|--------|
| Load unit into transport | `cActionLoad` | — (exposed, never called) | **EXPOSED** |
| Unload / activate unit | `cActionActivate` | — (exposed, never called) | **EXPOSED** |
| Transport cargo view | `Title~Cargo` — list stored units | — | **MISSING** |
| Resource capacity in transporter | CHANGELOG 0.2.11 | — | **MISSING** |
| Resource transfer between units | `cActionTransfer` | — (exposed, never called) | **EXPOSED** |
| Transfer dialog (slider, type) | Yes | — | **MISSING** |
| Repair unit | `cActionRepairReload` | — (exposed, never called) | **EXPOSED** |
| Reload ammo | `cActionRepairReload` (reload mode) | — (exposed, never called) | **EXPOSED** |

### 2J — Mining & Resources

| Element | Original | Godot | Status |
|---------|----------|-------|--------|
| Mining allocation menu | `Title~Mine` / "Allocation menu" | — | **MISSING** |
| Metal/Oil/Gold sliders | `cActionResourceDistribution` | — (exposed, never called) | **EXPOSED** |
| Survey for resources | `cVehicle::doSurvey()` | — | **MISSING** |
| Resource overlay on map | Toggleable, colour-coded by type | — | **MISSING** |
| Resource discovery notification | Surveyor finds deposit | — | **MISSING** |
| Energy balance display | `getEnergyProd()` / `getEnergyNeed()` | — (partially exposed) | **MISSING** |
| Energy shortage warning | Report type | — | **MISSING** |
| Sub-base connectivity display | `cBase` / `cSubBase` | — | **MISSING** |

### 2K — Special Unit Actions

| Element | Original | Godot | Status |
|---------|----------|-------|--------|
| Infiltrator steal | `cActionStealDisable` (steal mode) | — (exposed, never called) | **EXPOSED** |
| Infiltrator disable | `cActionStealDisable` (disable mode) | — (exposed, never called) | **EXPOSED** |
| Mine laying | `cActionMinelayerStatus` | — (exposed, never called) | **EXPOSED** |
| Mine clearing | `cActionMinelayerStatus` (clear mode) | — (exposed, never called) | **EXPOSED** |
| Terrain / rubble clearing | `cActionClear` | — (exposed, never called) | **EXPOSED** |
| Self-destruct building | `cActionSelfDestroy` | — (exposed, never called) | **EXPOSED** |
| Rubble rendering after destruction | `cMapField::getRubble()` | — | **MISSING** |
| Mine rendering (own visible, enemy hidden) | `cMapField::getMine()` | — | **MISSING** |

### 2L — Overlays & Toggles

| Element | Original | Godot | Status |
|---------|----------|-------|--------|
| Survey overlay | Toggle | — | **MISSING** |
| Hits overlay | Toggle | — | **MISSING** |
| Scan overlay | Toggle | — | **MISSING** |
| Status overlay | Toggle | — | **MISSING** |
| Ammo overlay | Toggle | — | **MISSING** |
| Grid overlay | Toggle | — | **MISSING** |
| Colour overlay | Toggle | — | **MISSING** |
| Range overlay | Toggle (attack range circles) | Range shown on unit select | **PARTIAL** |
| Fog of war overlay | Toggle | Fog is always on | **PARTIAL** |
| Lock overlay | Toggle | — | **MISSING** |

### 2M — End Turn

| Element | Original | Godot | Status |
|---------|----------|-------|--------|
| End Turn button | Yes | Yes | **DONE** |
| Hot Seat turn transition | Screen + "Ready" button | Yes | **DONE** |
| Turn-end deadline enforcement | `cTurnTimeDeadline` auto-ends | — | **MISSING** |
| Turn time clock display | Countdown timer | — | **MISSING** |
| New turn report | `sNewTurnReport` | — | **MISSING** |

---

## Journey 3: End-Game

| Element | Original | Godot | Status |
|---------|----------|-------|--------|
| Victory detection (elimination) | `playerHasWon` signal | — | **MISSING** |
| Victory detection (turn limit) | `victoryTurns` check | — | **MISSING** |
| Victory detection (points) | `victoryPoints` check | — | **MISSING** |
| Defeat detection | `playerHasLost` signal | — | **MISSING** |
| Sudden death mode | `suddenDeathMode` signal | — | **MISSING** |
| End-game statistics screen | `Title~GameOver`, `sGameOverStat` | — | **MISSING** |
| Built units tally | `GameOver~BuiltUnits` | — | **MISSING** |
| Built buildings tally | `GameOver~BuiltBuildings` | — | **MISSING** |
| Lost units tally | `GameOver~LostUnits` | — | **MISSING** |
| Lost buildings tally | `GameOver~LostBuildings` | — | **MISSING** |
| Score history graph | `pointsHistory` | — | **MISSING** |
| Return to main menu | Yes | — (no end-game flow) | **MISSING** |
| Victory / defeat music | Context music switch | — | **MISSING** |

---

## Journey 4: Settings & Meta Features

### 4A — Preferences / Options Screen

> Language string: `Title~Options`

| Element | Original | Godot | Status |
|---------|----------|-------|--------|
| Preferences screen | `Title~Options` | — | **MISSING** |
| Animations on/off | Display setting | — | **MISSING** |
| Shadows on/off | Display setting | — | **MISSING** |
| Alpha effects on/off | Display setting | — | **MISSING** |
| Damage effects on/off | Display setting | — | **MISSING** |
| Vehicle tracks on/off | Display setting | — | **MISSING** |
| 3D effects toggle | `Settings~3D` | — | **MISSING** |
| Autosave toggle | Setting | — | **MISSING** |
| Music volume | Audio setting | — (AudioManager exists) | **MISSING** UI |
| SFX volume | Audio setting | — (AudioManager exists) | **MISSING** UI |
| Voice volume | Audio setting | — | **MISSING** |
| Scroll speed | Configurable | Hardcoded `PAN_SPEED := 600.0` | **MISSING** |
| Language selection | Setting | — | **MISSING** |

### 4B — Save / Load

| Element | Original | Godot | Status |
|---------|----------|-------|--------|
| Save game dialog | In-game menu | — (never called) | **EXPOSED** |
| Save slot list | `engine.get_save_game_list()` | — (never called) | **EXPOSED** |
| Save slot metadata (date, turn, map, players) | `engine.get_save_game_info()` | — (never called) | **EXPOSED** |
| Load game screen (main menu) | `Title~Load` | Button disabled | **STUB** |
| Load game screen (in-game) | Quick load | — | **MISSING** |
| Auto-save at turn boundaries | Configurable frequency | — | **MISSING** |
| "Continue" last auto-save on main menu | Quick resume | — | **MISSING** |
| Hot Seat save/load | Tagged with game type | — | **MISSING** |
| Multiplayer save/load | Lobby `MU_MSG_SAVESLOTS` | — | **MISSING** |

### 4C — Keyboard Shortcuts

| Element | Original | Godot | Status |
|---------|----------|-------|--------|
| RTS hotkeys (A=attack, S=stop, etc.) | Yes | — | **MISSING** |
| Unit group hotkeys (Ctrl+1-9, 1-9) | CHANGELOG 0.2.7 | — | **MISSING** |
| Saved camera positions (F5-F8 / Alt+F5-F8) | CHANGELOG 0.2.10 | — | **MISSING** |
| Path preview (Shift+Left-Mouse) | CHANGELOG 0.2.11 | — | **MISSING** |
| Screenshot (Alt+C) | `Comp~Screenshot_Done` | — | **MISSING** |

### 4D — Notifications & Event Log

| Element | Original | Godot | Status |
|---------|----------|-------|--------|
| "Unit under attack" alert | `savedreport.h` — Attacked | — | **MISSING** |
| "Unit destroyed" alert | Destroyed report | — | **MISSING** |
| "Unit detected" alert | Detected report | — | **MISSING** |
| "Unit disabled" alert | Disabled report | — | **MISSING** |
| "Path interrupted" alert | PathInterrupted report | — | **MISSING** |
| "Production complete" notification | Report type | — | **MISSING** |
| "Research complete" notification | Report type | — | **MISSING** |
| "Building disabled" notification | BuildingDisabled report | — | **MISSING** |
| "Resource low" warning | ResourceLow report | — | **MISSING** |
| "Resource insufficient" warning | ResourceInsufficient report | — | **MISSING** |
| Scrollable event log | Turn-by-turn log | — | **MISSING** |
| Click event to jump to location | Camera jump | — | **MISSING** |

### 4E — Reports & Statistics (In-Game)

| Element | Original | Godot | Status |
|---------|----------|-------|--------|
| Casualties report screen | `cCasualtiesTracker` | — | **MISSING** |
| Player statistics panel | Built/lost vehicles/buildings | — (exposed, never called) | **EXPOSED** |
| Unit list / army overview | Filterable list of all units | — | **MISSING** |
| Unit filter: Air / Ground / Sea / Stationary | Filter buttons | — | **MISSING** |
| Unit filter: Damaged / Fighting / Producing / Stealth | Filter buttons | — | **MISSING** |
| Economy summary | Resource income/expenditure | — | **MISSING** |

### 4F — Other Meta Features

| Element | Original | Godot | Status |
|---------|----------|-------|--------|
| Credits / About screen | `data/ABOUT`, `Title~Credits` | — | **MISSING** |
| Intro movie | MVE player (CHANGELOG 0.2.2) | — | **N/A** (no movie file) |
| In-game chat | Chat panel | Yes (`chat_panel.gd`) | **DONE** |
| Console / chat commands | `/help`, `/pause`, `/kick`, `/turnend`, `/mark`, debug cmds | — | **MISSING** |

---

## Journey 5: Multiplayer-Specific Features

| Element | Original | Godot | Status |
|---------|----------|-------|--------|
| Host game (create server) | `cLobbyServer` | Yes (lobby scene) | **DONE** |
| Join game (connect to server) | `cLobbyClient` | Yes (lobby scene) | **DONE** |
| Lobby player list | `MU_MSG_PLAYERLIST` | Yes | **DONE** |
| Lobby chat | `MU_MSG_CHAT` | Yes | **DONE** |
| Lobby ready state | `MU_MSG_IDENTIFIKATION` | — | **MISSING** |
| Map download from host | `cMapDownloadMessageHandler` | — (signal exists) | **PARTIAL** |
| Map download progress bar | Progress display | — | **MISSING** |
| Map checksum validation | CRC checking | — | **MISSING** |
| Freeze mode display | `cFreezeModes` — Pause / WaitForClient / WaitForServer / WaitForTurnend | `network_status.gd` partial | **PARTIAL** |
| Show which player we're waiting for | Freeze detail | — | **MISSING** |
| Model re-synchronisation | `resyncClientModel()` | — | **MISSING** |
| Desync detection | Checksum mismatch | — | **MISSING** |
| Player disconnect handling | `connection_lost` signal | — (exposed) | **EXPOSED** |
| Player reconnection | Rejoin flow (`WANT_REJOIN_GAME`) | — | **MISSING** |
| AI takeover for disconnected player | — | — | **MISSING** |
| Team assignment | `Title~Team` | — | **MISSING** |
| Saved game slots in lobby | `MU_MSG_SAVESLOTS` | — | **MISSING** |

---

# PART B — FEATURE COUNT SUMMARY

| Journey | Total items | DONE | PARTIAL | MISSING/EXPOSED/STUB |
|---------|-------------|------|---------|----------------------|
| 1. Menu → Game Start | 44 | 16 | 2 | **26** |
| 2. In-Game Turn | 89 | 16 | 5 | **68** |
| 3. End-Game | 12 | 0 | 0 | **12** |
| 4. Settings & Meta | 42 | 1 | 0 | **41** |
| 5. Multiplayer | 16 | 4 | 2 | **10** |
| **TOTAL** | **203** | **37** | **9** | **157** |

**The Godot build currently implements ~18% of the original game's features.**

---

# PART C — IMPLEMENTATION ROADMAP

> Re-phased based on the user-journey audit. Phases now follow gameplay order:
> you cannot play the game properly without the earlier phases, so they come first.

## Phase 18: Pre-Game Setup Flow — **IMPLEMENTED**

> Players now choose their starting units (spending credits) and landing positions
> before the game starts. Hot Seat mode shows transition screens between players.

| # | Item | Status | Effort |
|---|------|--------|--------|
| 18.1 | Unit Purchase Screen (`Title~Choose_Units`) | **DONE** | Large |
| 18.2 | Expose `get_purchasable_vehicles()` from C++ | **DONE** | Medium |
| 18.3 | Expose `get_initial_landing_units()` from C++ | **DONE** | Medium |
| 18.4 | Landing Position Selection screen | **DONE** | Large |
| 18.5 | Expose `check_landing_position()` from C++ | **DONE** | Small |
| 18.6 | Clan Detail Screen (`get_clan_details()` exposed) | **DONE** | Medium |
| 18.7 | Pre-game Upgrade Purchasing tab | **MOVED → 21.7** | Medium |
| 18.8 | Wire purchased units + landing position into game init | **DONE** | Medium |
| 18.9 | Hot Seat: sequential shopping with transition screens | **DONE** | Medium |
| 18.10 | Remove hardcoded starting units (fallback kept for dev/test) | **DONE** | Small |

## Phase 19: Core Unit Actions — **IMPLEMENTED**

> All core unit commands are now wired: sentry, manual fire, load/unload, repair/reload,
> resource transfer, mine laying/clearing, infiltrator steal/disable, rubble clearing,
> self-destruct, auto-survey, rename. Visual state badges show on the map.

| # | Item | Status | Effort |
|---|------|--------|--------|
| 19.1 | Sentry mode toggle + visual indicator (eye badge) | **DONE** | Small |
| 19.2 | Manual fire mode toggle + visual indicator (crosshair badge) | **DONE** | Small |
| 19.3 | Reaction fire system (engine auto-fires; visual animation polish pending) | **DONE** | Large |
| 19.4 | Load unit into transport + cargo view panel | **DONE** | Medium |
| 19.5 | Unload / activate stored unit (click-to-place) | **DONE** | Medium |
| 19.6 | Repair & reload (click target after pressing button) | **DONE** | Medium |
| 19.7 | Resource transfer dialog (slider + resource type picker) | **DONE** | Medium |
| 19.8 | Infiltrator steal & disable (click target after pressing button) | **DONE** | Medium |
| 19.9 | Mine laying / clearing (toggle buttons) | **DONE** | Medium |
| 19.10 | Terrain / rubble clearing | **DONE** | Small |
| 19.11 | Self-destruct building | **DONE** | Small |
| 19.12 | Auto-move (surveyor AI) | **DONE** | Medium |
| 19.13 | Unit rename (dialog popup) | **DONE** | Small |

## Phase 20: In-Game Information & HUD — **IMPLEMENTED**

> All HUD information displays are now wired: resources, humans, score, turn timer,
> unit info popup, experience/rank, dated indicator, and 2x2 unit rendering.

| # | Item | Status | Effort |
|---|------|--------|--------|
| 20.1 | Full unit status screen (INFO button + popup with BBCode) | **DONE** | Medium |
| 20.2 | Energy balance in HUD resource bar (was already done) | **DONE** | Small |
| 20.3 | Human resources in HUD (Humans: X/Y +Z) | **DONE** | Small |
| 20.4 | Score display for Points victory (top bar) | **DONE** | Small |
| 20.5 | Turn timer / countdown display (color-coded urgency) | **DONE** | Medium |
| 20.6 | Turn-end deadline enforcement (C++ exposed + timer display) | **DONE** | Medium |
| 20.7 | Disabled unit indicator (pulsing red X overlay) | **DONE** | Small |
| 20.8 | Unit experience / rank display (commando ranks in unit panel + info) | **DONE** | Small |
| 20.9 | "Dated" unit indicator (version comparison, yellow label) | **DONE** | Small |
| 20.10 | 2x2 (big) unit rendering & selection (vehicles + buildings) | **DONE** | Medium |

## Phase 21: Research & Upgrades — `IMPLEMENTED`

| # | Item | Status | Effort |
|---|------|--------|--------|
| 21.1 | Research panel (`Title~Labs`) — 8 areas, allocation, progress | **DONE** | Large |
| 21.2 | Gold upgrades menu (`Title~Upgrades_Menu`) | **DONE** | Large |
| 21.3 | Vehicle upgrade at depot | **DONE** | Medium |
| 21.4 | Building upgrade + "Upgrade All" | **DONE** | Medium |
| 21.5 | Research complete notification | **DONE** | Small |
| 21.6 | Upgrade cost display | **DONE** | Small |
| 21.7 | Pre-game upgrade purchasing (on Choose Units screen) | **DONE** | Medium |

**Implementation notes:**

**C++ (GDExtension):**
- `GamePlayer::get_research_remaining_turns()` — 8-element Array of turns to next level per area
- `GameActions::get_upgradeable_units(player_id)` — all unit types with gold upgrade info
- `GameActions::buy_unit_upgrade(player_id, id_first, id_second, stat_index)` — buy one stat upgrade
- `GameActions::get_vehicle_upgrade_cost(vehicle_id)` — metal cost to upgrade vehicle
- `GameActions::get_building_upgrade_cost(building_id)` — metal cost to upgrade building
- `GameEngine::get_pregame_upgrade_info(clan)` — pre-game upgrade info at research level 0

**GDScript:**
- Research panel: 8-row allocation panel with sliders, level display, turns remaining, Apply button
- Gold upgrades menu: scrollable list of unit types with per-stat BUY buttons and cost display
- UPGRADE / UPGRADE ALL command buttons shown for dated units (buildings and vehicles)
- Research notification toast on level-up
- Pre-game upgrade tab on choose_units.gd with toggle, stat display, and credit tracking

## Phase 22: Mining, Resources & Economy — `IMPLEMENTED`

| # | Item | Status | Effort |
|---|------|--------|--------|
| 22.1 | Mining allocation menu (`Title~Mine`) | **DONE** | Medium |
| 22.2 | Resource survey action (surveyor units) | **DONE** | Medium |
| 22.3 | Resource overlay on map (toggleable, colour-coded) | **DONE** | Medium |
| 22.4 | Resource discovery notification | **DONE** | Small |
| 22.5 | Energy shortage warning | **DONE** | Small |
| 22.6 | Sub-base connectivity display | **DONE** | Large |

**Implementation notes:**

**C++ (GDExtension):**
- `GamePlayer::has_resource_explored(pos)` — check if tile surveyed by player
- `GamePlayer::get_sub_bases()` — per-sub-base Array of Dicts with storage, production, energy, humans, building IDs

**GDScript:**
- Mining dialog: slider-based allocation (Metal/Oil/Gold) with max total enforcement, fires `mining_distribution_changed` signal → `GameActions.set_resource_distribution()`
- Survey command: "SURVEY" button on surveyors toggles auto-survey via `set_auto_move()`
- Resource overlay: "RESOURCES" toggle in bottom bar renders colour-coded deposits (blue=metal, dark=oil, yellow=gold) with density alpha scaling and value labels on surveyed tiles
- Resource discovery toast: notification shown when new resource deposits are found after surveyor movement
- Energy warning: on turn start, checks energy balance and shows orange/red warning toast if `need > production`
- Sub-base panel: "BASES" button opens scrollable panel showing each sub-base's storage, net production, energy balance, and human counts

## Phase 23: Notifications & Event Log — `IMPLEMENTED`

| # | Item | Status | Effort |
|---|------|--------|--------|
| 23.1 | "Unit under attack" alert with camera jump | **DONE** | Medium |
| 23.2 | "Unit destroyed" alert | **DONE** | Small |
| 23.3 | "Production complete" notification | **DONE** | Small |
| 23.4 | "Research complete" notification | **DONE** | Small |
| 23.5 | Resource warnings (low, insufficient) | **DONE** | Small |
| 23.6 | Scrollable event log with jump-to-location | **DONE** | Medium |
| 23.7 | New turn report summary | **DONE** | Medium |

**Implementation notes:**

**C++ (GDExtension):**
- Refactored signal wiring into `GameEngine::connect_model_signals()` helper (eliminates 5x duplication)
- New Godot signals: `unit_attacked(player_id, unit_id, name, pos)`, `unit_destroyed(player_id, unit_id, name, pos)`, `unit_disabled(unit_id, name, pos)`, `build_error(player_id, error_type)`, `sudden_death()`
- Connected `cPlayer::unitAttacked`, `cPlayer::unitDestroyed`, `cPlayer::buildErrorBuildPositionBlocked`, `cPlayer::buildErrorInsufficientMaterial`, `cModel::unitDisabled`, `cModel::suddenDeathMode`

**GDScript:**
- Alert system: queued alert display with auto-camera-jump, fade-out animation, sequential queue processing
- Event log: scrollable "LOG" panel with timestamped entries, "> jump" buttons for positioned events, Clear button
- Turn report: popup panel on turn start summarising research completions, energy/resource shortages, worker shortages
- Production complete: detected by checking factory build list state at turn start
- Resource warnings: per-resource low/insufficient checks added to event log on turn start
- Build error alerts: "position blocked" and "insufficient material" shown as orange alerts

## Phase 24: Save/Load System — `IMPLEMENTED`

| # | Item | Status | Effort |
|---|------|--------|--------|
| 24.1 | Save game dialog (slot list, name input) | **DONE** | Medium |
| 24.2 | Load game screen (main menu) | **DONE** | Medium |
| 24.3 | Load game screen (in-game) | **DONE** | Medium |
| 24.4 | Auto-save at turn boundaries | **DONE** | Medium |
| 24.5 | "Continue" option on main menu | **DONE** | Small |

**Implementation notes:**

**GDScript:**
- Save dialog: slot list showing save name/turn/map/date, name input, "New Save Slot" option, slot selection highlights
- Load dialog (main menu): Window popup listing all saves with click-to-load, Cancel button
- Load dialog (in-game): same dialog opened from pause menu Load button, reloads scene with `load_mode` config
- Pause menu: added "Save Game" and "Load Game" buttons between Resume and Settings
- Auto-save: slot 10, triggered on every turn start (after turn 1), name format "Turn X - Autosave"
- Continue button: added to main menu before "LOAD GAME", loads auto-save slot 10
- GameManager: new `load_saved_game(slot)` method for clean scene transition to loaded game
- main_game.gd: `load_mode` handling in `_start_game()` calls `engine.load_game(slot)` instead of new_game

## Phase 25: Map Overlays & Toggles — `IMPLEMENTED`

| # | Item | Status | Effort |
|---|------|--------|--------|
| 25.1 | Survey overlay toggle | **DONE** | Small |
| 25.2 | Hits overlay toggle | **DONE** | Small |
| 25.3 | Scan overlay toggle | **DONE** | Small |
| 25.4 | Status overlay toggle | **DONE** | Small |
| 25.5 | Ammo overlay toggle | **DONE** | Small |
| 25.6 | Grid overlay toggle | **DONE** | Small |
| 25.7 | Colour overlay toggle | **DONE** | Small |
| 25.8 | Fog of war overlay toggle | **DONE** | Small |
| 25.9 | Lock overlay toggle | **DONE** | Small |
| 25.10 | Minimap zoom & attack-units-only filter | **DONE** | Small |

**Implementation notes:**

**GDScript:**
- Overlay toolbar: 9 toggle buttons (SVY, HP, SCN, STS, AMO, CLR, LCK, GRD, FOG) at bottom-left
- Generic stat overlay system in `overlay_renderer.gd`: draws per-unit text/color on tiles
- Survey (SVY): reuses Phase 22 resource overlay showing surveyed deposits
- Hits (HP): shows HP/max with green/yellow/red colour coding per health ratio
- Scan (SCN): shows scan range value in cyan
- Status (STS): shows state flags (DIS/SEN/MAN/WRK or OK)
- Ammo (AMO): shows ammo/max with colour coding by remaining ratio
- Colour (CLR): highlights tiles by owner colour (translucent fill)
- Lock (LCK): shows "LOCK" label only on sentry units with amber background
- Grid (GRD): draws tile grid lines across visible viewport
- Fog (FOG): toggles fog of war on/off (button ON = fog disabled for debug)
- Minimap: zoom toggle (1x/2x), "Armed" toggle filters to attack-capable units only

## Phase 26: Construction & Building Enhancements — `IMPLEMENTED`

| # | Item | Status | Effort |
|---|------|--------|--------|
| 26.1 | Resource cost display before placement | **DONE** | Small |
| 26.2 | Build time estimate display | **DONE** | Small |
| 26.3 | Cancel construction in progress | **DONE** | Small |
| 26.4 | Turbo build (speed multiplier) | **DONE** | Medium |
| 26.5 | Road / bridge / platform building | **DONE** | Large |
| 26.6 | Bridge / platform rendering | **DONE** | Medium |
| 26.7 | Connector buildings (base network visualisation) | **DONE** | Medium |

**Implementation notes:**

**C++ (GDExtension):**
- `GameUnit::get_turbo_build_info(building_type_id)` — Returns turbo build costs/turns for speeds 0/1/2 as Dictionary `{turns_0, cost_0, turns_1, cost_1, turns_2, cost_2}`
- `GameUnit::can_build_path()` — Returns true if vehicle can build roads/bridges/platforms (`canBuildPath`)
- `GameUnit::get_connection_flags()` — Returns building connection directions `{BaseN, BaseE, BaseS, BaseW, BaseBN, BaseBE, BaseBS, BaseBW, connects_to_base}`
- `GameUnit::get_max_build_factor()` — Returns max turbo build factor (0=no turbo, >1=turbo available)
- `GameActions::start_build_path(vehicle_id, type_id, speed, start, end)` — Start path building from start to end position via `cActionStartBuild` with `pathEndPosition`

**GDScript:**
- Build panel: shows turbo build costs/turns (1x/2x/4x buttons) per building entry via `get_turbo_build_info()`, emits `building_selected_ex` with speed
- Build preview: shows real-time cost/time/speed in tile label during placement hover
- Cancel construction: "CANCEL BUILD" button shown when constructing vehicle selected, calls `actions.stop()` which triggers `cActionStop`
- Turbo build: speed 0/1/2 selected from build panel, passed to `start_build()` — speeds: 0=1x, 1=2x (4x metal), 2=4x (12x metal)
- Path building: "PATH BUILD" button on `canBuildPath` vehicles, click-to-set-end triggers `start_build_path()` with `pathEndPosition`
- Connector overlay: "NET" toggle button draws base connection lines between buildings using `get_connection_flags()`, colour-coded per player
- `overlay_renderer.gd`: new `_draw_connector_overlay()` draws node highlights and directional connection lines for 1x1 and 2x2 buildings
- `unit_renderer.gd`: buildings include `connects_to_base` flag in render data

## Phase 27: End-Game — `IMPLEMENTED`

| # | Item | Status | Effort |
|---|------|--------|--------|
| 27.1 | Victory detection (all three types) | **DONE** | Medium |
| 27.2 | Defeat detection | **DONE** | Medium |
| 27.3 | Sudden death mode | **DONE** | Small |
| 27.4 | End-game statistics screen (`Title~GameOver`) | **DONE** | Large |
| 27.5 | Built / lost tallies | **DONE** | Small |
| 27.6 | Score history graph | **DONE** | Medium |
| 27.7 | Return to main menu flow | **DONE** | Small |
| 27.8 | Victory / defeat music | **DONE** | Small |

**Implementation notes:**

**C++ (GDExtension):**
- `GamePlayer::get_score_history()` — Returns `PackedInt32Array` of per-turn score history via `cPlayer::getScore(turn)`
- `GamePlayer::get_num_eco_spheres()` — Returns working EcoSphere count via `cPlayer::getNumEcoSpheres()`
- `GamePlayer::get_total_upgrade_cost()` — Returns total upgrade cost from `sGameOverStat`
- `GamePlayer::get_game_over_stats()` — Returns full stats Dictionary: built/lost vehicles/buildings, factories, mines, upgrade cost, score, eco spheres, alive counts
- `GameEngine::get_victory_settings()` — Returns `{type, target_turns, target_points}` from game settings
- `GameEngine::is_in_sudden_death()` — Returns true if turn limit exceeded (sudden death phase)

**GDScript:**
- Victory detection: all 3 types (Elimination, Turn Limit, Points) already wired via `player_won`/`player_lost` signals from C++ engine; enhanced with victory type details in end screen
- Defeat detection: `player_lost` signal fires when `mayHaveOffensiveUnit()` returns false; shows defeat screen with elimination message
- Sudden death: `sudden_death` signal sets `_sudden_death_active` flag, shows alert and event log entry; victory screen notes "Decided in Sudden Death mode"
- Statistics screen: `game_over_screen.gd` completely rewritten with per-player stat rows (name, score, built/lost tallies, alive units), colour-coded by player
- Score graph: `Line2D`-based score history graph drawn in GraphContainer with per-player coloured lines, auto-scaled axes
- Built/lost tallies: shown per player as "V: +X/-Y  B: +X/-Y" using `get_game_over_stats()`
- Return to menu: "Return to Menu" button calls `GameManager.go_to_main_menu()` with music stop
- Victory/defeat audio: "victory" and "defeat" sound entries added to AudioManager global sounds (placeholder .ogg files); music stops on game end
- Score display: HUD top bar now shows score for all victory types (not just Points mode), with target for Points games

## Phase 28: Reports & Statistics — `IMPLEMENTED`

| # | Item | Status | Effort |
|---|------|--------|--------|
| 28.1 | Casualties report screen | **DONE** | Medium |
| 28.2 | Player statistics panel | **DONE** | Medium |
| 28.3 | Unit list / army overview (filterable) | **DONE** | Large |
| 28.4 | Economy summary | **DONE** | Medium |

**Implementation notes:**

**C++ (GDExtension):**
- `GameEngine::get_casualties_report()` — Returns Array of Dictionaries with per-unit-type loss data across all players from `cCasualtiesTracker`. Each entry: `{unit_type_id, unit_name, is_building, losses: [{player_id, player_name, count}], total_losses}`
- Exposed existing `cCasualtiesTracker` data via `cModel::getCasualtiesTracker()` — tracks unit losses by type and player, with `getUnitTypesWithLosses()` and `getCasualtiesOfUnitType()`
- Leverages already-exposed `GamePlayer::get_game_over_stats()`, `get_economy_summary()`, `get_player_vehicles()`, `get_player_buildings()`

**GDScript:**
- **Casualties panel** (`game_hud.gd`): `_create_casualties_panel()` creates scrollable Window with per-unit-type rows showing Type, Name, Total losses, and Per-player breakdown. `show_casualties_report()` populates from `get_casualties_report()` data
- **Player statistics panel** (`game_hud.gd`): `_create_player_stats_panel()` creates Window with per-player frames showing score, built/lost tallies, alive units, eco spheres, upgrade cost, and factory/mine counts. Colour-coded per player with defeated indicator
- **Army overview** (`game_hud.gd`): `_create_army_panel()` creates filterable Window with OptionButton filter (All/Vehicles/Buildings/Combat/Damaged/Idle), unit totals, and scrollable list with columns: Name, HP, Dmg, Arm, Ammo, Spd, Status, Position + jump button. `_on_army_filter_changed()` re-filters without re-querying engine
- **Economy summary** (`game_hud.gd`): `_create_economy_panel()` creates Window showing credits, resource storage/net production for metal/oil/gold, energy balance, human balance, and research levels in a 4-column grid
- **Global buttons**: Added LOSSES, STATS, ARMY, ECON buttons to `_create_global_buttons()` bottom bar. These emit via `command_pressed` signal
- **Global command handling**: Refactored `_on_command_pressed()` in `main_game.gd` to handle global commands (reports, research, bases, overlays) before the unit-selection guard, so they work regardless of whether a unit is selected
- `main_game.gd`: New command functions `_cmd_open_casualties()`, `_cmd_open_player_stats()`, `_cmd_open_army()`, `_cmd_open_economy()` gather data from engine and pass to HUD show functions

## Phase 29: Keyboard Shortcuts & UX — `IMPLEMENTED`

| # | Item | Status | Effort |
|---|------|--------|--------|
| 29.1 | RTS hotkeys (A, S, G, etc.) | **DONE** | Medium |
| 29.2 | Unit group hotkeys (Ctrl+1-9, 1-9) | **DONE** | Medium |
| 29.3 | Box-select / shift-click multi-select | **DONE** | Medium |
| 29.4 | Saved camera positions (F5-F8 / Alt+F5-F8) | **DONE** | Small |
| 29.5 | Path preview (Shift+hover) | **DONE** | Small |
| 29.6 | Screenshot (Alt+C) | **DONE** | Small |

**Implementation notes:**

**GDScript — `main_game.gd`:**
- **RTS hotkeys** (29.1): `_handle_keyboard_shortcut()` dispatches keypresses to existing command handler. Key map: A=manual fire, S=sentry, G=stop, R=repair, L=load, U=unload/activate, M=mining, B=build, I=info, T=transfer, X/Del=self-destruct, N=rename, V=survey, P=path build, C=clear rubble. Enter=end turn, Space=cycle idle units, Tab/Shift+Tab=cycle all units
- **Unit groups** (29.2): Ctrl+1-9 assigns current selection (single or multi) to group via `_assign_unit_group()`. 1-9 recalls group via `_recall_unit_group()` — validates surviving units, selects first, centers camera. Groups stored in `_unit_groups` Dictionary
- **Box-select** (29.3): Shift+left-click-drag draws a selection rectangle (`ColorRect` overlay). `_start_box_select()` / `_update_box_select()` / `_finish_box_select()` — converts screen rect to world tiles, finds all player vehicles in rect. Sets `_selected_units` array for multi-select. Used by group assignment
- **Path preview** (29.5): `_shift_held` flag tracked from `InputEventKey.shift_pressed`. When Shift is held during hover, `_update_hover_preview()` shows pathfinder path even to tiles outside the current movement range — useful for planning future turns
- **Screenshot** (29.6): Alt+C triggers `_take_screenshot()` — captures viewport image, saves as PNG to `user://screenshots/` with timestamp filename. Shows alert confirmation
- **Unit cycling**: Space cycles to next idle unit (has movement points, not sentry/disabled/working). Tab/Shift+Tab cycles through all units. Both center the camera on the selected unit
- **Global command fix**: Global hotkeys (Enter, Space, Tab) work without a selected unit. Unit command hotkeys require a selection

**GDScript — `game_camera.gd`:**
- **Saved positions** (29.4): `save_position(slot)` / `recall_position(slot)` store/restore camera position in 4 slots. Alt+F5-F8 saves, F5-F8 recalls. `_saved_positions` array stores Vector2 positions

## Phase 30: Preferences & Settings — **LOW PRIORITY**

| # | Item | Status | Effort |
|---|------|--------|--------|
| 30.1 | Preferences screen UI | **MISSING** | Medium |
| 30.2 | Display settings (animations, shadows, effects, tracks) | **MISSING** | Medium |
| 30.3 | Audio settings (music/SFX/voice volume) | **MISSING** UI | Medium |
| 30.4 | Scroll speed configuration | **MISSING** | Small |
| 30.5 | Autosave toggle | **MISSING** | Small |
| 30.6 | Credits / About screen | **MISSING** | Small |

## Phase 31: Advanced Unit Features — **LOW PRIORITY**

| # | Item | Status | Effort |
|---|------|--------|--------|
| 31.1 | Plane system (flight height, landing platforms) | **MISSING** | Large |
| 31.2 | Stealth & detection system | **MISSING** | Large |
| 31.3 | Rubble system (rendering + clearing) | **MISSING** | Medium |
| 31.4 | Mine rendering (own visible, enemy hidden) | **MISSING** | Medium |
| 31.5 | Vehicle tracks on terrain | **MISSING** | Small |
| 31.6 | Group movement / formation | **MISSING** | Large |
| 31.7 | End-move actions (attack/load/enter after move) | **MISSING** | Medium |
| 31.8 | Resume interrupted move | **MISSING** | Small |
| 31.9 | Drive-and-fire capability | **MISSING** | Medium |

## Phase 32: Multiplayer Enhancements — **LOW PRIORITY**

| # | Item | Status | Effort |
|---|------|--------|--------|
| 32.1 | Team assignment in lobby | **MISSING** | Medium |
| 32.2 | Lobby ready state display | **MISSING** | Small |
| 32.3 | Map download progress bar | **MISSING** | Medium |
| 32.4 | Map checksum validation | **MISSING** | Small |
| 32.5 | Model re-synchronisation & desync detection | **MISSING** | Large |
| 32.6 | Player disconnect handling + AI takeover | **EXPOSED** | Large |
| 32.7 | Player reconnection | **MISSING** | Large |
| 32.8 | Freeze/pause detail (which player, timeout) | **PARTIAL** | Medium |
| 32.9 | Console / chat commands | **MISSING** | Medium |
| 32.10 | Multiplayer save game slots in lobby | **MISSING** | Medium |

## Phase 33: Audio & Polish — **LOW PRIORITY**

| # | Item | Status | Effort |
|---|------|--------|--------|
| 33.1 | Verify all unit sounds (move, attack, build, die) | **PARTIAL** | Medium |
| 33.2 | UI click sounds | **MISSING** | Small |
| 33.3 | Alert sounds (under attack, unit lost) | **MISSING** | Small |
| 33.4 | Music transitions (menu → game → victory/defeat) | **MISSING** | Medium |
| 33.5 | Team colour mask recolouring system (magenta `#FF00FF`) | **PARTIAL** | Large |

---

# PART D — REFERENCE

## Art Pipeline: Team / Player Colour Convention

When creating or updating unit sprite assets, the following convention **must** be used
so the engine can recolour units per-player at runtime.

### Designated mask colour: **Magenta `#FF00FF` (R 255, G 0, B 255)**

| Item | Detail |
|------|--------|
| **Mask colour (hex)** | `#FF00FF` |
| **Mask colour (RGB)** | `(255, 0, 255)` |
| **Tolerance** | Exact match only — no anti-aliasing on the mask edges; keep them pixel-crisp |
| **Where to paint it** | Any area of a unit sprite that should adopt the owning player's colour (e.g. hull panels, insignia, flag, trim) |
| **File format** | PNG-32 with transparency. The magenta mask pixels must be **fully opaque** (`A = 255`) |
| **Shadow sprites** | Do **NOT** add mask colour to shadow (`shw*.png`) files |
| **FX sprites** | Do **NOT** add mask colour to FX/explosion/muzzle sprites |

### How it works at runtime

The unit renderer (`unit_renderer.gd`) will:

1. On first load of a sprite, scan for any pixel whose RGB matches `#FF00FF` exactly.
2. If mask pixels are found, generate a per-player variant by replacing every mask pixel
   with the player's team colour (using the same hue but preserving the pixel's
   original luminance so shading detail is kept).
3. Cache the recoloured texture so the replacement only happens once per player per sprite.

If **no** mask pixels are detected the renderer falls back to the current whole-sprite
tint system (`PLAYER_TINT_STRENGTH` modulation), so existing/legacy assets continue to
work without modification.

### Current player colours (defined in `unit_renderer.gd`)

| Slot | Name | Hex |
|------|------|-----|
| 0 | Blue | `#3366FF` |
| 1 | Red | `#FF3333` |
| 2 | Green | `#33CC33` |
| 3 | Yellow | `#FFCC00` |
| 4 | Purple | `#CC33CC` |
| 5 | Orange | `#FF8000` |
| 6 | Cyan | `#00CCCC` |
| 7 | Gray | `#999999` |

---

## Quick Reference: GDExtension Methods Exposed but Never Called

These methods are already bound in C++ and ready to use — they just need GDScript UI:

```
# GameActions (game_actions.h)
actions.toggle_sentry(unit_id)
actions.toggle_manual_fire(unit_id)
actions.load_unit(unit_id, transport_id)
actions.activate_unit(transport_id, stored_unit_id)
actions.repair_reload(supplier_id, target_id)
actions.transfer_resources(from_id, to_id, type, amount)
actions.steal_disable(infiltrator_id, target_id, steal_mode)
actions.clear_area(unit_id)
actions.self_destroy(building_id)
actions.rename_unit(unit_id, new_name)
actions.set_minelayer_status(unit_id, mode)
actions.set_auto_move(unit_id, enabled)
actions.change_research(player_id, allocations)
actions.upgrade_vehicle(building_id, vehicle_id)
actions.upgrade_building(building_id, upgrade_all)
actions.set_resource_distribution(building_id, metal, oil, gold)

# GameEngine (game_engine.h)
engine.save_game(slot)
engine.load_game(slot)
engine.get_save_game_list()
engine.get_save_game_info(slot)

# GamePlayer (game_player.h)
player.get_score()
player.get_human_balance()
player.get_research_levels()
player.get_research_centers_per_area()
player.get_built_vehicles_count()
player.get_lost_vehicles_count()
player.get_built_buildings_count()
player.get_lost_buildings_count()

# GameUnit (game_unit.h)
unit.is_disabled()
unit.get_disabled_turns()
unit.is_sentry_active()
unit.is_manual_fire()
unit.get_stored_resources()
unit.get_stored_units_count()
unit.get_energy_production()
unit.get_energy_need()
unit.can_be_upgraded()
```

---

## Hardcoded Values That Must Be Replaced

| Location | What's hardcoded | Should be |
|----------|------------------|-----------|
| `game_setup.cpp:446-448` | Landing positions evenly spaced horizontally | Player-chosen positions |
| `game_setup.cpp:457-469` | Starting units (1 Constructor + 2 Tanks + 1 Surveyor) | Player-purchased units |
| `game_setup.cpp:312-320` | Game settings defaults (bridgehead, alien, game type, victory, resources) | UI-configured (partially fixed by `setup_custom_game_ex`) |
| `main_game.gd:5` | `TILE_SIZE := 64` | From engine |
| `main_game.gd:718` | `build_speed := 1` | From unit data |
| `main_game.gd:835` | `engine.advance_ticks(10)` | Configurable tick count |
| `move_animator.gd:10` | `MOVE_SPEED := 200.0` | From unit speed stat |
| `game_camera.gd:4-8` | Zoom/pan/edge scroll constants | From preferences |
| `new_game_setup.gd:41` | `DEFAULT_CREDITS := 150` | From engine defaults |
| `new_game_setup.gd:370` | `default_enabled := 2` player count | From last-used setting |
