#include "game_engine.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

void GameEngine::_bind_methods() {
    ClassDB::bind_method(D_METHOD("get_engine_version"), &GameEngine::get_engine_version);
    ClassDB::bind_method(D_METHOD("get_engine_status"), &GameEngine::get_engine_status);
    ClassDB::bind_method(D_METHOD("is_engine_initialized"), &GameEngine::is_engine_initialized);
    ClassDB::bind_method(D_METHOD("initialize_engine"), &GameEngine::initialize_engine);
}

GameEngine::GameEngine() {
    engine_initialized = false;
}

GameEngine::~GameEngine() {
}

String GameEngine::get_engine_version() const {
    return String("MaXtreme Engine v0.1.0 (M.A.X.R. 0.2.17 core)");
}

String GameEngine::get_engine_status() const {
    if (engine_initialized) {
        return String("Engine initialized and ready");
    }
    return String("Engine not yet initialized");
}

bool GameEngine::is_engine_initialized() const {
    return engine_initialized;
}

void GameEngine::initialize_engine() {
    // Phase 1: Just set the flag
    // Phase 2+: This will load game data, initialize cModel, etc.
    engine_initialized = true;
    UtilityFunctions::print("[MaXtreme] Engine initialized successfully!");
    UtilityFunctions::print("[MaXtreme] ", get_engine_version());
}
