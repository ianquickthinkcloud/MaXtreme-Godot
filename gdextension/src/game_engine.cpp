#include "game_engine.h"
#include "game_map.h"
#include "game_player.h"
#include "game_unit.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

// M.A.X.R. core engine includes
#include "game/data/model.h"
#include "game/data/map/map.h"
#include "game/data/player/player.h"
#include "game/data/units/unitdata.h"
#include "game/data/units/vehicle.h"
#include "game/data/units/building.h"
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
}

GameEngine::GameEngine() {
    engine_initialized = false;
}

GameEngine::~GameEngine() {
    // unique_ptr handles cleanup
}

// --- Lifecycle ---

String GameEngine::get_engine_version() const {
    return String("MaXtreme Engine v0.2.0 (M.A.X.R. 0.2.17 core)");
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
