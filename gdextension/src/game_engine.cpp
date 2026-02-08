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
#include "game/logic/turntimeclock.h"
#include "game/logic/action/actionendturn.h"
#include "game/logic/action/actionstartturn.h"
#include "game/logic/server.h"
#include "game/logic/client.h"
#include "game/connectionmanager.h"
#include "game/data/savegame.h"
#include "game/data/savegameinfo.h"
#include "game/data/gamesettings.h"
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

    // Data loading (Phase 8)
    ClassDB::bind_method(D_METHOD("load_game_data"), &GameEngine::load_game_data);
    ClassDB::bind_method(D_METHOD("get_available_maps"), &GameEngine::get_available_maps);
    ClassDB::bind_method(D_METHOD("get_available_clans"), &GameEngine::get_available_clans);
    ClassDB::bind_method(D_METHOD("get_unit_data_info"), &GameEngine::get_unit_data_info);

    // Phase 18: Pre-game setup data
    ClassDB::bind_method(D_METHOD("get_purchasable_vehicles", "clan"), &GameEngine::get_purchasable_vehicles);
    ClassDB::bind_method(D_METHOD("get_initial_landing_units", "clan", "start_credits", "bridgehead_type"), &GameEngine::get_initial_landing_units);
    ClassDB::bind_method(D_METHOD("get_clan_details"), &GameEngine::get_clan_details);
    ClassDB::bind_method(D_METHOD("check_landing_position", "map_name", "pos"), &GameEngine::check_landing_position);

    // Phase 21: Pre-game upgrade info
    ClassDB::bind_method(D_METHOD("get_pregame_upgrade_info", "clan"), &GameEngine::get_pregame_upgrade_info);

    // Game initialization (Phase 4, updated Phase 8)
    ClassDB::bind_method(D_METHOD("new_game_test"), &GameEngine::new_game_test);
    ClassDB::bind_method(D_METHOD("new_game", "map_name", "player_names", "player_colors", "player_clans", "start_credits"),
                         &GameEngine::new_game);
    ClassDB::bind_method(D_METHOD("new_game_ex", "game_settings"), &GameEngine::new_game_ex);

    // Save/Load (Phase 13)
    ClassDB::bind_method(D_METHOD("save_game", "slot", "save_name"), &GameEngine::save_game);
    ClassDB::bind_method(D_METHOD("load_game", "slot"), &GameEngine::load_game);
    ClassDB::bind_method(D_METHOD("get_save_game_list"), &GameEngine::get_save_game_list);
    ClassDB::bind_method(D_METHOD("get_save_game_info", "slot"), &GameEngine::get_save_game_info);

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

    // Phase 20: Turn timer & victory
    ClassDB::bind_method(D_METHOD("get_turn_time_remaining"), &GameEngine::get_turn_time_remaining);
    ClassDB::bind_method(D_METHOD("has_turn_deadline"), &GameEngine::has_turn_deadline);
    ClassDB::bind_method(D_METHOD("is_victory_condition_met"), &GameEngine::is_victory_condition_met);
    ClassDB::bind_method(D_METHOD("get_victory_type"), &GameEngine::get_victory_type);

    // Networking (Phase 16)
    ClassDB::bind_method(D_METHOD("get_network_mode"), &GameEngine::get_network_mode);
    ClassDB::bind_method(D_METHOD("is_multiplayer"), &GameEngine::is_multiplayer);

    // Signals for turn system events
    ADD_SIGNAL(MethodInfo("turn_ended"));
    ADD_SIGNAL(MethodInfo("turn_started", PropertyInfo(Variant::INT, "turn_number")));
    ADD_SIGNAL(MethodInfo("player_finished_turn", PropertyInfo(Variant::INT, "player_id")));
    ADD_SIGNAL(MethodInfo("player_won", PropertyInfo(Variant::INT, "player_id")));
    ADD_SIGNAL(MethodInfo("player_lost", PropertyInfo(Variant::INT, "player_id")));

    // Network signals
    ADD_SIGNAL(MethodInfo("freeze_mode_changed", PropertyInfo(Variant::STRING, "mode")));
    ADD_SIGNAL(MethodInfo("connection_lost"));
}

GameEngine::GameEngine() {
    engine_initialized = false;
    network_mode = SINGLE_PLAYER;
}

GameEngine::~GameEngine() {
    // Stop server/client threads before cleanup
    if (server) {
        server->stop();
    }
    // unique_ptr handles cleanup
}

// --- Model accessor ---

cModel* GameEngine::get_active_model() const {
    switch (network_mode) {
        case HOST:
            if (server) return const_cast<cModel*>(&server->getModel());
            break;
        case CLIENT:
            if (client) return const_cast<cModel*>(&client->getModel());
            break;
        case SINGLE_PLAYER:
        default:
            return model.get();
    }
    return model.get();
}

// --- Networking (Phase 16) ---

bool GameEngine::setup_as_host(int port) {
    // This is a simplified setup; the real flow goes through GameLobby
    UtilityFunctions::print("[MaXtreme] setup_as_host on port ", port);
    network_mode = HOST;
    return true;
}

bool GameEngine::setup_as_client() {
    UtilityFunctions::print("[MaXtreme] setup_as_client");
    network_mode = CLIENT;
    return true;
}

void GameEngine::accept_lobby_handoff(std::shared_ptr<cConnectionManager> conn_mgr,
                                       std::unique_ptr<cServer> srv,
                                       std::unique_ptr<cClient> cli,
                                       NetworkMode mode) {
    connection_manager = conn_mgr;
    server = std::move(srv);
    client = std::move(cli);
    network_mode = mode;
    engine_initialized = true;

    // Connect model signals from the active model
    cModel* m = get_active_model();
    if (m) {
        m->turnEnded.connect([this]() {
            call_deferred("emit_signal", "turn_ended");
        });
        m->newTurnStarted.connect([this](const sNewTurnReport&) {
            auto* am = get_active_model();
            auto tc = am ? am->getTurnCounter() : nullptr;
            int turn = tc ? tc->getTurn() : 0;
            call_deferred("emit_signal", "turn_started", turn);
        });
        m->playerFinishedTurn.connect([this](const cPlayer& player) {
            call_deferred("emit_signal", "player_finished_turn", player.getId());
        });
        m->playerHasWon.connect([this](const cPlayer& player) {
            call_deferred("emit_signal", "player_won", player.getId());
        });
        m->playerHasLost.connect([this](const cPlayer& player) {
            call_deferred("emit_signal", "player_lost", player.getId());
        });
    }

    if (client) {
        client->freezeModeChanged.connect([this]() {
            call_deferred("emit_signal", "freeze_mode_changed", String("changed"));
        });
        client->connectionToServerLost.connect([this]() {
            call_deferred("emit_signal", "connection_lost");
        });
    }

    UtilityFunctions::print("[MaXtreme] Lobby handoff complete, mode=",
                            mode == HOST ? "HOST" : "CLIENT");
}

String GameEngine::get_network_mode() const {
    switch (network_mode) {
        case HOST: return String("host");
        case CLIENT: return String("client");
        default: return String("single_player");
    }
}

bool GameEngine::is_multiplayer() const {
    return network_mode != SINGLE_PLAYER;
}

cClient* GameEngine::get_client() const {
    return client.get();
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
    auto* m = get_active_model();
    if (!m) return -1;
    auto turnCounter = m->getTurnCounter();
    return turnCounter ? turnCounter->getTurn() : 0;
}

int GameEngine::get_player_count() const {
    auto* m = get_active_model();
    if (!m) return 0;
    return static_cast<int>(m->getPlayerList().size());
}

// --- Map access ---

Ref<GameMap> GameEngine::get_map() const {
    Ref<GameMap> game_map;
    game_map.instantiate();
    auto* m = get_active_model();
    if (m) {
        game_map->set_internal_map(m->getMap());
    }
    return game_map;
}

String GameEngine::get_map_name() const {
    auto* m = get_active_model();
    if (!m) return String("(no model)");
    auto map = m->getMap();
    if (!map) return String("(no map loaded)");
    auto fn = map->getFilename().string();
    if (fn.empty()) return String("(empty map)");
    return String(fn.c_str());
}

// --- Player access ---

Ref<GamePlayer> GameEngine::get_player(int index) const {
    Ref<GamePlayer> game_player;
    game_player.instantiate();
    auto* m = get_active_model();
    if (!m) return game_player;

    const auto& players = m->getPlayerList();
    if (index < 0 || index >= static_cast<int>(players.size())) return game_player;

    game_player->set_internal_player(players[index]);
    return game_player;
}

Array GameEngine::get_all_players() const {
    Array result;
    auto* m = get_active_model();
    if (!m) return result;

    const auto& players = m->getPlayerList();
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
    auto* m = get_active_model();
    if (!m) return game_unit;

    const auto& players = m->getPlayerList();
    if (player_index < 0 || player_index >= static_cast<int>(players.size())) return game_unit;

    const auto& player = players[player_index];

    auto* vehicle = player->getVehicleFromId(static_cast<unsigned int>(unit_id));
    if (vehicle) {
        game_unit->set_internal_unit(vehicle);
        return game_unit;
    }

    auto* building = player->getBuildingFromId(static_cast<unsigned int>(unit_id));
    if (building) {
        game_unit->set_internal_unit(building);
        return game_unit;
    }

    return game_unit;
}

Array GameEngine::get_player_vehicles(int player_index) const {
    Array result;
    auto* m = get_active_model();
    if (!m) return result;

    const auto& players = m->getPlayerList();
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
    auto* m = get_active_model();
    if (!m) return result;

    const auto& players = m->getPlayerList();
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

// --- Phase 18: Pre-game setup data ---

Array GameEngine::get_purchasable_vehicles(int clan) const {
    return GameSetup::get_purchasable_vehicles(clan);
}

Array GameEngine::get_initial_landing_units(int clan, int start_credits, String bridgehead_type) const {
    return GameSetup::get_initial_landing_units(clan, start_credits, bridgehead_type);
}

Array GameEngine::get_clan_details() const {
    return GameSetup::get_clan_details();
}

bool GameEngine::check_landing_position(String map_name, Vector2i pos) const {
    return GameSetup::check_landing_position(map_name, pos);
}

// --- Phase 21: Pre-game upgrade info ---

Array GameEngine::get_pregame_upgrade_info(int clan) const {
    return GameSetup::get_pregame_upgrade_info(clan);
}

// --- Action system ---

Ref<GameActions> GameEngine::get_actions() const {
    Ref<GameActions> actions;
    actions.instantiate();
    auto* m = get_active_model();
    if (m) {
        actions->set_internal_model(m);
    }
    // In multiplayer, route actions through cClient
    if (client) {
        actions->set_internal_client(client.get());
    }
    return actions;
}

// --- Pathfinding (Phase 7) ---

Ref<GamePathfinder> GameEngine::get_pathfinder() const {
    Ref<GamePathfinder> pf;
    pf.instantiate();
    auto* m = get_active_model();
    if (m) {
        pf->set_internal_model(m);
    }
    return pf;
}

// --- Data loading (Phase 8) ---

bool GameEngine::load_game_data() {
    return GameSetup::ensure_data_loaded();
}

Array GameEngine::get_available_maps() const {
    return GameSetup::get_available_maps();
}

Array GameEngine::get_available_clans() const {
    return GameSetup::get_available_clans();
}

Dictionary GameEngine::get_unit_data_info() const {
    return GameSetup::get_unit_data_info();
}

// --- Game initialization (Phase 4, updated Phase 8) ---

Dictionary GameEngine::new_game_test() {
    if (!engine_initialized) {
        initialize_engine();
    }
    // Reset model for new game
    model = std::make_unique<cModel>();
    auto result = GameSetup::setup_test_game(*model);

    // Connect model signals to Godot signals
    if (result.has("success") && bool(result["success"]) && model) {
        model->turnEnded.connect([this]() {
            call_deferred("emit_signal", "turn_ended");
        });
        model->newTurnStarted.connect([this](const sNewTurnReport&) {
            auto tc = model->getTurnCounter();
            int turn = tc ? tc->getTurn() : 0;
            call_deferred("emit_signal", "turn_started", turn);
        });
        model->playerFinishedTurn.connect([this](const cPlayer& player) {
            call_deferred("emit_signal", "player_finished_turn", player.getId());
        });
        model->playerHasWon.connect([this](const cPlayer& player) {
            call_deferred("emit_signal", "player_won", player.getId());
        });
        model->playerHasLost.connect([this](const cPlayer& player) {
            call_deferred("emit_signal", "player_lost", player.getId());
        });
    }

    return result;
}

Dictionary GameEngine::new_game(String map_name, Array player_names, Array player_colors, Array player_clans, int start_credits) {
    if (!engine_initialized) {
        initialize_engine();
    }
    // Reset model for new game
    model = std::make_unique<cModel>();
    auto result = GameSetup::setup_custom_game(*model, map_name, player_names, player_colors, player_clans, start_credits);

    // Connect model signals to Godot signals
    if (result.has("success") && bool(result["success"]) && model) {
        model->turnEnded.connect([this]() {
            call_deferred("emit_signal", "turn_ended");
        });
        model->newTurnStarted.connect([this](const sNewTurnReport&) {
            auto tc = model->getTurnCounter();
            int turn = tc ? tc->getTurn() : 0;
            call_deferred("emit_signal", "turn_started", turn);
        });
        model->playerFinishedTurn.connect([this](const cPlayer& player) {
            call_deferred("emit_signal", "player_finished_turn", player.getId());
        });
        model->playerHasWon.connect([this](const cPlayer& player) {
            call_deferred("emit_signal", "player_won", player.getId());
        });
        model->playerHasLost.connect([this](const cPlayer& player) {
            call_deferred("emit_signal", "player_lost", player.getId());
        });
    }

    return result;
}

Dictionary GameEngine::new_game_ex(Dictionary game_settings) {
    if (!engine_initialized) {
        initialize_engine();
    }
    // Reset model for new game
    model = std::make_unique<cModel>();
    auto result = GameSetup::setup_custom_game_ex(*model, game_settings);

    // Connect model signals to Godot signals
    if (result.has("success") && bool(result["success"]) && model) {
        model->turnEnded.connect([this]() {
            call_deferred("emit_signal", "turn_ended");
        });
        model->newTurnStarted.connect([this](const sNewTurnReport&) {
            auto tc = model->getTurnCounter();
            int turn = tc ? tc->getTurn() : 0;
            call_deferred("emit_signal", "turn_started", turn);
        });
        model->playerFinishedTurn.connect([this](const cPlayer& player) {
            call_deferred("emit_signal", "player_finished_turn", player.getId());
        });
        model->playerHasWon.connect([this](const cPlayer& player) {
            call_deferred("emit_signal", "player_won", player.getId());
        });
        model->playerHasLost.connect([this](const cPlayer& player) {
            call_deferred("emit_signal", "player_lost", player.getId());
        });
    }

    return result;
}

// --- Save/Load (Phase 13) ---

bool GameEngine::save_game(int slot, String save_name) {
    auto* m = get_active_model();
    if (!m) {
        UtilityFunctions::push_warning("[MaXtreme] save_game: No active game to save");
        return false;
    }
    try {
        cSavegame savegame;
        std::string name = save_name.utf8().get_data();
        savegame.save(*m, slot, name);
        UtilityFunctions::print("[MaXtreme] Game saved to slot ", slot, ": ", save_name);
        return true;
    } catch (const std::exception& e) {
        UtilityFunctions::push_error("[MaXtreme] save_game failed: ", e.what());
        return false;
    }
}

Dictionary GameEngine::load_game(int slot) {
    Dictionary result;
    try {
        if (!engine_initialized) {
            initialize_engine();
        }
        // Reset model for loading
        model = std::make_unique<cModel>();

        cSavegame savegame;
        savegame.loadModel(*model, slot);

        // Reconnect model signals
        model->turnEnded.connect([this]() {
            call_deferred("emit_signal", "turn_ended");
        });
        model->newTurnStarted.connect([this](const sNewTurnReport&) {
            auto tc = model->getTurnCounter();
            int turn = tc ? tc->getTurn() : 0;
            call_deferred("emit_signal", "turn_started", turn);
        });
        model->playerFinishedTurn.connect([this](const cPlayer& player) {
            call_deferred("emit_signal", "player_finished_turn", player.getId());
        });
        model->playerHasWon.connect([this](const cPlayer& player) {
            call_deferred("emit_signal", "player_won", player.getId());
        });
        model->playerHasLost.connect([this](const cPlayer& player) {
            call_deferred("emit_signal", "player_lost", player.getId());
        });

        result["success"] = true;
        result["slot"] = slot;
        result["turn"] = get_turn_number();
        result["player_count"] = get_player_count();
        result["map_name"] = get_map_name();
        UtilityFunctions::print("[MaXtreme] Game loaded from slot ", slot);
    } catch (const std::exception& e) {
        result["success"] = false;
        result["error"] = String(e.what());
        UtilityFunctions::push_error("[MaXtreme] load_game failed: ", e.what());
    }
    return result;
}

Array GameEngine::get_save_game_list() {
    Array result;
    try {
        std::vector<cSaveGameInfo> saves;
        fillSaveGames(0, 100, saves);
        for (const auto& info : saves) {
            Dictionary d;
            d["slot"] = info.number;
            d["name"] = String(info.gameName.c_str());
            d["date"] = String(info.date.c_str());
            d["turn"] = static_cast<int>(info.turn);
            d["map"] = String(info.mapFilename.string().c_str());

            Array players;
            for (const auto& p : info.players) {
                Dictionary pd;
                pd["name"] = String(p.getName().c_str());
                pd["id"] = p.getNr();
                pd["defeated"] = p.isDefeated();
                players.push_back(pd);
            }
            d["players"] = players;
            result.push_back(d);
        }
    } catch (const std::exception& e) {
        UtilityFunctions::push_warning("[MaXtreme] get_save_game_list: ", e.what());
    }
    return result;
}

Dictionary GameEngine::get_save_game_info(int slot) {
    Dictionary result;
    try {
        cSavegame savegame;
        auto info = savegame.loadSaveInfo(slot);
        result["slot"] = info.number;
        result["name"] = String(info.gameName.c_str());
        result["date"] = String(info.date.c_str());
        result["turn"] = static_cast<int>(info.turn);
        result["map"] = String(info.mapFilename.string().c_str());

        Array players;
        for (const auto& p : info.players) {
            Dictionary pd;
            pd["name"] = String(p.getName().c_str());
            pd["id"] = p.getNr();
            pd["defeated"] = p.isDefeated();
            players.push_back(pd);
        }
        result["players"] = players;
    } catch (const std::exception& e) {
        result["error"] = String(e.what());
    }
    return result;
}

// --- Turn System & Game Loop (Phase 5) ---

void GameEngine::advance_tick() {
    // In multiplayer mode, ticks are driven by the lockstep timer automatically
    if (network_mode != SINGLE_PLAYER) return;
    auto* m = get_active_model();
    if (!m) return;
    m->advanceGameTime();
}

void GameEngine::advance_ticks(int count) {
    if (network_mode != SINGLE_PLAYER) return;
    auto* m = get_active_model();
    if (!m) return;
    for (int i = 0; i < count; i++) {
        m->advanceGameTime();
    }
}

int GameEngine::get_game_time() const {
    auto* m = get_active_model();
    if (!m) return 0;
    return static_cast<int>(m->getGameTime());
}

bool GameEngine::end_player_turn(int player_id) {
    auto* m = get_active_model();
    if (!m) return false;

    cPlayer* player = m->getPlayer(player_id);
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

    m->handlePlayerFinishedTurn(*player);
    return true;
}

bool GameEngine::start_player_turn(int player_id) {
    auto* m = get_active_model();
    if (!m) return false;

    cPlayer* player = m->getPlayer(player_id);
    if (!player) {
        UtilityFunctions::push_warning("[MaXtreme] start_player_turn: player ", player_id, " not found");
        return false;
    }

    if (player->isDefeated) return false;

    m->handlePlayerStartTurn(*player);
    return true;
}

bool GameEngine::is_turn_active() const {
    auto* m = get_active_model();
    if (!m) return false;
    const auto& players = m->getPlayerList();
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
    auto* m = get_active_model();
    if (!m) return false;
    const auto& players = m->getPlayerList();
    for (const auto& p : players) {
        if (!p->isDefeated && !p->getHasFinishedTurn()) {
            return false;
        }
    }
    return true;
}

String GameEngine::get_turn_state() const {
    auto* m = get_active_model();
    if (!m) return String("no_model");

    if (all_players_finished()) {
        return String("processing");
    }
    return String("active");
}

Dictionary GameEngine::get_game_state() const {
    Dictionary state;
    auto* m = get_active_model();
    if (!m) {
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
    state["game_id"] = static_cast<int>(m->getGameId());
    state["network_mode"] = get_network_mode();

    Array player_states;
    const auto& players = m->getPlayerList();
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
    auto* m = get_active_model();
    if (!m) {
        result["processed"] = false;
        return result;
    }

    // In multiplayer, ticks are automatic -- just report current state
    if (network_mode != SINGLE_PLAYER) {
        result["processed"] = true;
        result["game_time"] = get_game_time();
        result["turn"] = get_turn_number();
        result["turn_changed"] = false;
        result["is_turn_active"] = is_turn_active();
        return result;
    }

    int prev_turn = get_turn_number();

    m->advanceGameTime();

    int new_turn = get_turn_number();

    result["processed"] = true;
    result["game_time"] = get_game_time();
    result["turn"] = new_turn;
    result["turn_changed"] = (new_turn != prev_turn);
    result["is_turn_active"] = is_turn_active();

    return result;
}

// ========== Phase 20: Turn Timer & Victory ==========

double GameEngine::get_turn_time_remaining() const {
    auto* m = get_active_model();
    if (!m) return -1.0;
    auto clock = m->getTurnTimeClock();
    if (!clock || !clock->hasDeadline()) return -1.0;
    auto remaining = clock->getTimeTillFirstDeadline();
    return std::chrono::duration<double>(remaining).count();
}

bool GameEngine::has_turn_deadline() const {
    auto* m = get_active_model();
    if (!m) return false;
    auto clock = m->getTurnTimeClock();
    return clock && clock->hasDeadline();
}

bool GameEngine::is_victory_condition_met() const {
    auto* m = get_active_model();
    if (!m) return false;
    auto settings = m->getGameSettings();
    if (!settings) return false;

    const auto& players = m->getPlayerList();
    switch (settings->victoryConditionType) {
        case eGameSettingsVictoryCondition::Death: {
            // Only one non-defeated player remains
            int alive = 0;
            for (const auto& p : players) {
                if (!p->isDefeated) alive++;
            }
            return alive <= 1;
        }
        case eGameSettingsVictoryCondition::Turns: {
            return m->getTurnCounter()->getTurn() >= static_cast<int>(settings->victoryTurns);
        }
        case eGameSettingsVictoryCondition::Points: {
            for (const auto& p : players) {
                if (!p->isDefeated && p->getScore() >= static_cast<int>(settings->victoryPoints))
                    return true;
            }
            return false;
        }
        default:
            return false;
    }
}

String GameEngine::get_victory_type() const {
    auto* m = get_active_model();
    if (!m) return String("none");
    auto settings = m->getGameSettings();
    if (!settings) return String("none");
    switch (settings->victoryConditionType) {
        case eGameSettingsVictoryCondition::Turns:
            return String("turn_limit");
        case eGameSettingsVictoryCondition::Points:
            return String("points");
        case eGameSettingsVictoryCondition::Death:
        default:
            return String("elimination");
    }
}
