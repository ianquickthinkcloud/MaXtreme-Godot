#include "game_engine.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

// M.A.X.R. core engine includes
#include "game/data/model.h"
#include "game/data/map/map.h"
#include "game/data/player/player.h"
#include "game/data/units/unitdata.h"
#include "utility/log.h"

using namespace godot;

void GameEngine::_bind_methods() {
    ClassDB::bind_method(D_METHOD("get_engine_version"), &GameEngine::get_engine_version);
    ClassDB::bind_method(D_METHOD("get_engine_status"), &GameEngine::get_engine_status);
    ClassDB::bind_method(D_METHOD("is_engine_initialized"), &GameEngine::is_engine_initialized);
    ClassDB::bind_method(D_METHOD("initialize_engine"), &GameEngine::initialize_engine);
    ClassDB::bind_method(D_METHOD("get_turn_number"), &GameEngine::get_turn_number);
    ClassDB::bind_method(D_METHOD("get_map_name"), &GameEngine::get_map_name);
    ClassDB::bind_method(D_METHOD("get_player_count"), &GameEngine::get_player_count);
}

GameEngine::GameEngine() {
    engine_initialized = false;
}

GameEngine::~GameEngine() {
    // unique_ptr handles cleanup
}

String GameEngine::get_engine_version() const {
    return String("MaXtreme Engine v0.1.0 (M.A.X.R. 0.2.17 core)");
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
    // Create the core game model - this is THE central object of the M.A.X.R. engine
    model = std::make_unique<cModel>();

    engine_initialized = true;

    UtilityFunctions::print("[MaXtreme] Core C++ game engine initialized!");
    UtilityFunctions::print("[MaXtreme] ", get_engine_version());
    UtilityFunctions::print("[MaXtreme] cModel created - game state management active");
    UtilityFunctions::print("[MaXtreme] Turn counter: ", get_turn_number());
    UtilityFunctions::print("[MaXtreme] Player count: ", get_player_count());
}

int GameEngine::get_turn_number() const {
    if (!model) return -1;
    auto turnCounter = model->getTurnCounter();
    return turnCounter ? turnCounter->getTurn() : 0;
}

String GameEngine::get_map_name() const {
    if (!model) return String("(no model)");
    auto map = model->getMap();
    if (!map) return String("(no map loaded)");
    return String("Map loaded");
}

int GameEngine::get_player_count() const {
    if (!model) return 0;
    return static_cast<int>(model->getPlayerList().size());
}
