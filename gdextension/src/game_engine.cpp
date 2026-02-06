#include "game_engine.h"
#include "game_map.h"
#include "game_player.h"
#include "game_unit.h"
#include "game_actions.h"
#include "game_setup.h"
#include "game_pathfinder.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

// M.A.X.R. core engine includes
#include "game/data/model.h"
#include "game/data/map/map.h"
#include "game/data/player/player.h"
#include "game/data/units/unitdata.h"
#include "game/data/units/vehicle.h"
#include "game/data/units/building.h"
#include "game/logic/turncounter.h"
#include "game/logic/action/actionendturn.h"
#include "game/logic/action/actionstartturn.h"
#include "utility/log.h"

using namespace godot;

void GameEngine::_bind_methods() {
    // Lifecycle
    ClassDB::bind_method(D_METHOD("get_engine_version"), &GameEngine::get_engine_version);
    ClassDB::bind_method(D_METHOD("get_engine_status"), &GameEngine::get_engine_status);
    ClassDB::bind_method(D_METHOD("is_engine_initialized"), &GameEngine::is_engine_initialized);
    ClassDB::bind_method(D_METHOD("initialize_engine"), &GameEngine::initialize_engine);

    // Game state
    ClassDB::bind_method(D_METHOD("get_turn_number"), &GameEngine::get_turn_number);
    ClassDB::bind_method(D_METHOD("get_player_count"), &GameEngine::get_player_count);

    // Map access
    ClassDB::bind_method(D_METHOD("get_map"), &GameEngine::get_map);
    ClassDB::bind_method(D_METHOD("get_map_name"), &GameEngine::get_map_name);

    // Player access
    ClassDB::bind_method(D_METHOD("get_player", "index"), &GameEngine::get_player);
    ClassDB::bind_method(D_METHOD("get_all_players"), &GameEngine::get_all_players);

    // Unit access
    ClassDB::bind_method(D_METHOD("get_unit_by_id", "player_index", "unit_id"), &GameEngine::get_unit_by_id);
    ClassDB::bind_method(D_METHOD("get_player_vehicles", "player_index"), &GameEngine::get_player_vehicles);
    ClassDB::bind_method(D_METHOD("get_player_buildings", "player_index"), &GameEngine::get_player_buildings);

    // Action system
    ClassDB::bind_method(D_METHOD("get_actions"), &GameEngine::get_actions);

    // Pathfinding (Phase 7)
    ClassDB::bind_method(D_METHOD("get_pathfinder"), &GameEngine::get_pathfinder);

    // Game initialization (Phase 4)
    ClassDB::bind_method(D_METHOD("new_game_test"), &GameEngine::new_game_test);
    ClassDB::bind_method(D_METHOD("new_game", "player_names", "player_colors", "map_size", "start_credits"),
                         &GameEngine::new_game);

    // Turn system & game loop (Phase 5)
    ClassDB::bind_method(D_METHOD("advance_tick"), &GameEngine::advance_tick);
    ClassDB::bind_method(D_METHOD("advance_ticks", "count"), &GameEngine::advance_ticks);
    ClassDB::bind_method(D_METHOD("get_game_time"), &GameEngine::get_game_time);
    ClassDB::bind_method(D_METHOD("end_player_turn", "player_id"), &GameEngine::end_player_turn);
    ClassDB::bind_method(D_METHOD("start_player_turn", "player_id"), &GameEngine::start_player_turn);
    ClassDB::bind_method(D_METHOD("is_turn_active"), &GameEngine::is_turn_active);
    ClassDB::bind_method(D_METHOD("all_players_finished"), &GameEngine::all_players_finished);
    ClassDB::bind_method(D_METHOD("get_turn_state"), &GameEngine::get_turn_state);
    ClassDB::bind_method(D_METHOD("get_game_state"), &GameEngine::get_game_state);
    ClassDB::bind_method(D_METHOD("process_game_tick"), &GameEngine::process_game_tick);

    // Signals for turn system events
    ADD_SIGNAL(MethodInfo("turn_ended"));
    ADD_SIGNAL(MethodInfo("turn_started", PropertyInfo(Variant::INT, "turn_number")));
    ADD_SIGNAL(MethodInfo("player_finished_turn", PropertyInfo(Variant::INT, "player_id")));
    ADD_SIGNAL(MethodInfo("player_won", PropertyInfo(Variant::INT, "player_id")));
    ADD_SIGNAL(MethodInfo("player_lost", PropertyInfo(Variant::INT, "player_id")));
}

GameEngine::GameEngine() {
    engine_initialized = false;
}

GameEngine::~GameEngine() {
    // unique_ptr handles cleanup
}

// --- Lifecycle ---

String GameEngine::get_engine_version() const {
    return String("MaXtreme Engine v0.3.0 (M.A.X.R. 0.2.17 core)");
}

String GameEngine::get_engine_status() const {
    if (engine_initialized) {
        return String("Engine initialized - cModel active with ") +
               String::num_int64(get_player_count()) + String(" players, turn ") +
               String::num_int64(get_turn_number());
    }
    return String("Engine not yet initialized");
}

bool GameEngine::is_engine_initialized() const {
    return engine_initialized;
}

void GameEngine::initialize_engine() {
    model = std::make_unique<cModel>();
    engine_initialized = true;

    UtilityFunctions::print("[MaXtreme] Core C++ game engine initialized!");
    UtilityFunctions::print("[MaXtreme] ", get_engine_version());
    UtilityFunctions::print("[MaXtreme] cModel created - game state management active");
    UtilityFunctions::print("[MaXtreme] Data bridge: GameMap, GamePlayer, GameUnit classes ready");
}

// --- Game state ---

int GameEngine::get_turn_number() const {
    if (!model) return -1;
    auto turnCounter = model->getTurnCounter();
    return turnCounter ? turnCounter->getTurn() : 0;
}

int GameEngine::get_player_count() const {
    if (!model) return 0;
    return static_cast<int>(model->getPlayerList().size());
}

// --- Map access ---

Ref<GameMap> GameEngine::get_map() const {
    Ref<GameMap> game_map;
    game_map.instantiate();
    if (model) {
        game_map->set_internal_map(model->getMap());
    }
    return game_map;
}

String GameEngine::get_map_name() const {
    if (!model) return String("(no model)");
    auto map = model->getMap();
    if (!map) return String("(no map loaded)");
    auto fn = map->getFilename().string();
    if (fn.empty()) return String("(empty map)");
    return String(fn.c_str());
}

// --- Player access ---

Ref<GamePlayer> GameEngine::get_player(int index) const {
    Ref<GamePlayer> game_player;
    game_player.instantiate();
    if (!model) return game_player;

    const auto& players = model->getPlayerList();
    if (index < 0 || index >= static_cast<int>(players.size())) return game_player;

    game_player->set_internal_player(players[index]);
    return game_player;
}

Array GameEngine::get_all_players() const {
    Array result;
    if (!model) return result;

    const auto& players = model->getPlayerList();
    for (size_t i = 0; i < players.size(); i++) {
        Ref<GamePlayer> gp;
        gp.instantiate();
        gp->set_internal_player(players[i]);
        result.push_back(gp);
    }
    return result;
}

// --- Unit access ---

Ref<GameUnit> GameEngine::get_unit_by_id(int player_index, int unit_id) const {
    Ref<GameUnit> game_unit;
    game_unit.instantiate();
    if (!model) return game_unit;

    const auto& players = model->getPlayerList();
    if (player_index < 0 || player_index >= static_cast<int>(players.size())) return game_unit;

    const auto& player = players[player_index];

    // Search vehicles first
    auto* vehicle = player->getVehicleFromId(static_cast<unsigned int>(unit_id));
    if (vehicle) {
        game_unit->set_internal_unit(vehicle);
        return game_unit;
    }

    // Then buildings
    auto* building = player->getBuildingFromId(static_cast<unsigned int>(unit_id));
    if (building) {
        game_unit->set_internal_unit(building);
        return game_unit;
    }

    return game_unit;
}

Array GameEngine::get_player_vehicles(int player_index) const {
    Array result;
    if (!model) return result;

    const auto& players = model->getPlayerList();
    if (player_index < 0 || player_index >= static_cast<int>(players.size())) return result;

    const auto& player = players[player_index];
    for (const auto& vehicle : player->getVehicles()) {
        Ref<GameUnit> gu;
        gu.instantiate();
        gu->set_internal_unit(vehicle.get());
        result.push_back(gu);
    }
    return result;
}

Array GameEngine::get_player_buildings(int player_index) const {
    Array result;
    if (!model) return result;

    const auto& players = model->getPlayerList();
    if (player_index < 0 || player_index >= static_cast<int>(players.size())) return result;

    const auto& player = players[player_index];
    for (const auto& building : player->getBuildings()) {
        Ref<GameUnit> gu;
        gu.instantiate();
        gu->set_internal_unit(building.get());
        result.push_back(gu);
    }
    return result;
}

// --- Action system ---

Ref<GameActions> GameEngine::get_actions() const {
    Ref<GameActions> actions;
    actions.instantiate();
    if (model) {
        actions->set_internal_model(model.get());
    }
    return actions;
}

// --- Pathfinding (Phase 7) ---

Ref<GamePathfinder> GameEngine::get_pathfinder() const {
    Ref<GamePathfinder> pf;
    pf.instantiate();
    if (model) {
        pf->set_internal_model(model.get());
    }
    return pf;
}

// --- Game initialization (Phase 4) ---

Dictionary GameEngine::new_game_test() {
    // Delegate to new_game with default test parameters
    Array names;
    names.push_back(String("Player 1"));
    names.push_back(String("Player 2"));
    Array colors;
    colors.push_back(Color(0.0f, 0.0f, 1.0f));
    colors.push_back(Color(1.0f, 0.0f, 0.0f));
    return new_game(names, colors, 64, 150);
}

Dictionary GameEngine::new_game(Array player_names, Array player_colors, int map_size, int start_credits) {
    if (!engine_initialized) {
        initialize_engine();
    }
    // Reset model for new game
    model = std::make_unique<cModel>();
    auto result = GameSetup::setup_custom_game(*model, player_names, player_colors, map_size, start_credits);

    // Connect model signals to Godot signals
    if (result.has("success") && bool(result["success"]) && model) {
        // Turn ended signal
        model->turnEnded.connect([this]() {
            call_deferred("emit_signal", "turn_ended");
        });

        // New turn started signal
        model->newTurnStarted.connect([this](const sNewTurnReport&) {
            auto tc = model->getTurnCounter();
            int turn = tc ? tc->getTurn() : 0;
            call_deferred("emit_signal", "turn_started", turn);
        });

        // Player finished turn signal
        model->playerFinishedTurn.connect([this](const cPlayer& player) {
            call_deferred("emit_signal", "player_finished_turn", player.getId());
        });

        // Player won signal
        model->playerHasWon.connect([this](const cPlayer& player) {
            call_deferred("emit_signal", "player_won", player.getId());
        });

        // Player lost signal
        model->playerHasLost.connect([this](const cPlayer& player) {
            call_deferred("emit_signal", "player_lost", player.getId());
        });
    }

    return result;
}

// --- Turn System & Game Loop (Phase 5) ---

void GameEngine::advance_tick() {
    if (!model) return;
    model->advanceGameTime();
}

void GameEngine::advance_ticks(int count) {
    if (!model) return;
    for (int i = 0; i < count; i++) {
        model->advanceGameTime();
    }
}

int GameEngine::get_game_time() const {
    if (!model) return 0;
    return static_cast<int>(model->getGameTime());
}

bool GameEngine::end_player_turn(int player_id) {
    if (!model) return false;

    cPlayer* player = model->getPlayer(player_id);
    if (!player) {
        UtilityFunctions::push_warning("[MaXtreme] end_player_turn: player ", player_id, " not found");
        return false;
    }

    if (player->isDefeated) {
        UtilityFunctions::push_warning("[MaXtreme] end_player_turn: player ", player_id, " is defeated");
        return false;
    }

    if (player->getHasFinishedTurn()) {
        UtilityFunctions::push_warning("[MaXtreme] end_player_turn: player ", player_id, " already finished turn");
        return false;
    }

    model->handlePlayerFinishedTurn(*player);
    return true;
}

bool GameEngine::start_player_turn(int player_id) {
    if (!model) return false;

    cPlayer* player = model->getPlayer(player_id);
    if (!player) {
        UtilityFunctions::push_warning("[MaXtreme] start_player_turn: player ", player_id, " not found");
        return false;
    }

    if (player->isDefeated) return false;

    model->handlePlayerStartTurn(*player);
    return true;
}

bool GameEngine::is_turn_active() const {
    if (!model) return false;
    // A turn is "active" when players are issuing commands.
    // We detect this by checking that no turn-end processing is happening.
    // The turn-end states transition through: TurnActive -> ExecuteRemainingMovements -> ExecuteTurnStart
    // During TurnActive, players can issue commands.
    // We approximate this by checking if all players have NOT finished their turn yet
    // OR at least one player hasn't finished (in simultaneous mode).
    const auto& players = model->getPlayerList();
    bool anyActive = false;
    for (const auto& p : players) {
        if (!p->isDefeated && !p->getHasFinishedTurn()) {
            anyActive = true;
            break;
        }
    }
    return anyActive;
}

bool GameEngine::all_players_finished() const {
    if (!model) return false;
    const auto& players = model->getPlayerList();
    for (const auto& p : players) {
        if (!p->isDefeated && !p->getHasFinishedTurn()) {
            return false;
        }
    }
    return true;
}

String GameEngine::get_turn_state() const {
    if (!model) return String("no_model");

    // Check if all players finished (turn-end processing is happening or about to)
    if (all_players_finished()) {
        // Check if there are active move jobs (ExecuteRemainingMovements state)
        // We can't directly access turnEndState, but we can infer from game state
        return String("processing");
    }
    return String("active");
}

Dictionary GameEngine::get_game_state() const {
    Dictionary state;
    if (!model) {
        state["valid"] = false;
        return state;
    }

    state["valid"] = true;
    state["game_time"] = get_game_time();
    state["turn"] = get_turn_number();
    state["turn_state"] = get_turn_state();
    state["is_turn_active"] = is_turn_active();
    state["all_finished"] = all_players_finished();
    state["player_count"] = get_player_count();
    state["game_id"] = static_cast<int>(model->getGameId());

    // Per-player state
    Array player_states;
    const auto& players = model->getPlayerList();
    for (const auto& p : players) {
        Dictionary ps;
        ps["id"] = p->getId();
        ps["name"] = String(p->getName().c_str());
        ps["credits"] = p->getCredits();
        ps["defeated"] = p->isDefeated;
        ps["finished_turn"] = p->getHasFinishedTurn();
        ps["vehicles"] = static_cast<int>(p->getVehicles().size());
        ps["buildings"] = static_cast<int>(p->getBuildings().size());
        ps["score"] = p->getScore();
        player_states.push_back(ps);
    }
    state["players"] = player_states;

    return state;
}

Dictionary GameEngine::process_game_tick() {
    Dictionary result;
    if (!model) {
        result["processed"] = false;
        return result;
    }

    int prev_turn = get_turn_number();
    int prev_time = get_game_time();
    bool was_active = is_turn_active();

    // Advance one tick
    model->advanceGameTime();

    int new_turn = get_turn_number();
    int new_time = get_game_time();
    bool now_active = is_turn_active();

    result["processed"] = true;
    result["game_time"] = new_time;
    result["turn"] = new_turn;
    result["turn_changed"] = (new_turn != prev_turn);
    result["is_turn_active"] = now_active;

    return result;
}
