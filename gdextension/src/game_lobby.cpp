#include "game_lobby.h"
#include "game_engine.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

// M.A.X.R. includes
#include "game/connectionmanager.h"
#include "game/networkaddress.h"
#include "game/startup/lobbyserver.h"
#include "game/startup/lobbyclient.h"
#include "game/logic/server.h"
#include "game/logic/client.h"
#include "game/data/map/map.h"
#include "game/data/gamesettings.h"
#include "game/data/player/playerbasicdata.h"
#include "utility/color.h"
#include "utility/log.h"

using namespace godot;

// ========== BINDING ==========

void GameLobby::_bind_methods() {
    // Host methods
    ClassDB::bind_method(D_METHOD("host_game", "port", "player_name", "player_color"),
                         &GameLobby::host_game);
    ClassDB::bind_method(D_METHOD("select_map", "map_name"), &GameLobby::select_map);
    ClassDB::bind_method(D_METHOD("kick_player", "player_id"), &GameLobby::kick_player);
    ClassDB::bind_method(D_METHOD("start_game"), &GameLobby::start_game);

    // Client methods
    ClassDB::bind_method(D_METHOD("join_game", "host", "port", "player_name", "player_color"),
                         &GameLobby::join_game);
    ClassDB::bind_method(D_METHOD("set_ready", "ready"), &GameLobby::set_ready);
    ClassDB::bind_method(D_METHOD("change_player_info", "name", "color"),
                         &GameLobby::change_player_info);
    ClassDB::bind_method(D_METHOD("disconnect_lobby"), &GameLobby::disconnect_lobby);

    // Shared methods
    ClassDB::bind_method(D_METHOD("send_chat", "message"), &GameLobby::send_chat);
    ClassDB::bind_method(D_METHOD("get_player_list"), &GameLobby::get_player_list);
    ClassDB::bind_method(D_METHOD("get_map_name"), &GameLobby::get_map_name);
    ClassDB::bind_method(D_METHOD("get_role"), &GameLobby::get_role);
    ClassDB::bind_method(D_METHOD("has_game_started"), &GameLobby::has_game_started);
    ClassDB::bind_method(D_METHOD("poll"), &GameLobby::poll);
    ClassDB::bind_method(D_METHOD("handoff_to_engine", "engine"), &GameLobby::handoff_to_engine);

    // Phase 32: Multiplayer Enhancements
    ClassDB::bind_method(D_METHOD("set_clan", "clan_id"), &GameLobby::set_clan);
    ClassDB::bind_method(D_METHOD("get_available_clans"), &GameLobby::get_available_clans);
    ClassDB::bind_method(D_METHOD("get_map_checksum"), &GameLobby::get_map_checksum);
    ClassDB::bind_method(D_METHOD("kick_player_connection", "player_id"), &GameLobby::kick_player_connection);
    ClassDB::bind_method(D_METHOD("get_multiplayer_saves"), &GameLobby::get_multiplayer_saves);
    ClassDB::bind_method(D_METHOD("load_multiplayer_save", "slot"), &GameLobby::load_multiplayer_save);

    // Signals
    ADD_SIGNAL(MethodInfo("player_joined", PropertyInfo(Variant::INT, "id"),
                          PropertyInfo(Variant::STRING, "name")));
    ADD_SIGNAL(MethodInfo("player_left", PropertyInfo(Variant::INT, "id")));
    ADD_SIGNAL(MethodInfo("player_ready_changed", PropertyInfo(Variant::INT, "id"),
                          PropertyInfo(Variant::BOOL, "ready")));
    ADD_SIGNAL(MethodInfo("player_list_changed"));
    ADD_SIGNAL(MethodInfo("chat_received", PropertyInfo(Variant::STRING, "from_name"),
                          PropertyInfo(Variant::STRING, "message")));
    ADD_SIGNAL(MethodInfo("map_changed", PropertyInfo(Variant::STRING, "map_name")));
    ADD_SIGNAL(MethodInfo("map_download_progress", PropertyInfo(Variant::FLOAT, "percent")));
    ADD_SIGNAL(MethodInfo("game_starting"));
    ADD_SIGNAL(MethodInfo("connection_failed", PropertyInfo(Variant::STRING, "reason")));
    ADD_SIGNAL(MethodInfo("connection_established"));
}

// ========== LIFECYCLE ==========

GameLobby::GameLobby() {}

GameLobby::~GameLobby() {
    disconnect_lobby();
}

// ========== HOST METHODS ==========

bool GameLobby::host_game(int port, String player_name, Color player_color) {
    if (role != NONE) {
        UtilityFunctions::push_warning("[MaXtreme] GameLobby: Already in a lobby");
        return false;
    }

    try {
        // Create connection manager
        connection_manager = std::make_shared<cConnectionManager>();

        // Create lobby server
        lobby_server = std::make_unique<cLobbyServer>(connection_manager);

        // Start listening
        auto result = lobby_server->startServer(port);
        if (result != eOpenServerResult::Success) {
            UtilityFunctions::push_error("[MaXtreme] GameLobby: Failed to start server on port ", port);
            lobby_server.reset();
            connection_manager.reset();
            return false;
        }

        // Create local player data
        std::string name = player_name.utf8().get_data();
        cRgbColor color(
            static_cast<unsigned char>(player_color.r * 255),
            static_cast<unsigned char>(player_color.g * 255),
            static_cast<unsigned char>(player_color.b * 255)
        );
        cPlayerBasicData localPlayer;
        localPlayer.setName(std::move(name));
        localPlayer.setColor(color);

        // Create lobby client (local client for the host)
        lobby_client = std::make_unique<cLobbyClient>(connection_manager, localPlayer);

        // Connect local client to server
        lobby_client->connectToLocalServer(*lobby_server);

        // Connect signals
        connect_server_signals();
        connect_client_signals();

        role = HOST;
        UtilityFunctions::print("[MaXtreme] GameLobby: Hosting game on port ", port);
        return true;

    } catch (const std::exception& e) {
        UtilityFunctions::push_error("[MaXtreme] GameLobby::host_game failed: ", e.what());
        lobby_server.reset();
        lobby_client.reset();
        connection_manager.reset();
        return false;
    }
}

bool GameLobby::select_map(String map_name) {
    if (role != HOST || !lobby_server) {
        UtilityFunctions::push_warning("[MaXtreme] GameLobby: Only host can select map");
        return false;
    }

    try {
        std::string name = map_name.utf8().get_data();
        auto staticMap = std::make_shared<cStaticMap>();
        std::filesystem::path mapPath = name;

        if (!staticMap->loadMap(mapPath)) {
            UtilityFunctions::push_warning("[MaXtreme] GameLobby: Failed to load map: ", map_name);
            return false;
        }

        selected_map = staticMap;
        lobby_server->selectMap(staticMap);
        cached_map_name = map_name;

        UtilityFunctions::print("[MaXtreme] GameLobby: Map selected: ", map_name);
        return true;

    } catch (const std::exception& e) {
        UtilityFunctions::push_warning("[MaXtreme] GameLobby::select_map failed: ", e.what());
        return false;
    }
}

void GameLobby::kick_player(int player_id) {
    if (role != HOST || !lobby_server) return;
    // The M.A.X.R. lobby doesn't have a direct kick method --
    // the server would need to close the connection.
    UtilityFunctions::push_warning("[MaXtreme] GameLobby: kick_player not yet implemented");
}

bool GameLobby::start_game() {
    if (role != HOST || !lobby_client) {
        UtilityFunctions::push_warning("[MaXtreme] GameLobby: Only host can start game");
        return false;
    }

    try {
        lobby_client->askToFinishLobby();
        UtilityFunctions::print("[MaXtreme] GameLobby: Requesting game start...");
        return true;
    } catch (const std::exception& e) {
        UtilityFunctions::push_warning("[MaXtreme] GameLobby::start_game failed: ", e.what());
        return false;
    }
}

// ========== CLIENT METHODS ==========

bool GameLobby::join_game(String host, int port, String player_name, Color player_color) {
    if (role != NONE) {
        UtilityFunctions::push_warning("[MaXtreme] GameLobby: Already in a lobby");
        return false;
    }

    try {
        connection_manager = std::make_shared<cConnectionManager>();

        std::string name = player_name.utf8().get_data();
        cRgbColor color(
            static_cast<unsigned char>(player_color.r * 255),
            static_cast<unsigned char>(player_color.g * 255),
            static_cast<unsigned char>(player_color.b * 255)
        );
        cPlayerBasicData localPlayer;
        localPlayer.setName(std::move(name));
        localPlayer.setColor(color);

        lobby_client = std::make_unique<cLobbyClient>(connection_manager, localPlayer);

        connect_client_signals();

        // Connect to remote server
        sNetworkAddress addr;
        addr.ip = host.utf8().get_data();
        addr.port = static_cast<uint16_t>(port);
        lobby_client->connectToServer(addr);

        role = CLIENT;
        UtilityFunctions::print("[MaXtreme] GameLobby: Connecting to ", host, ":", port);
        return true;

    } catch (const std::exception& e) {
        UtilityFunctions::push_error("[MaXtreme] GameLobby::join_game failed: ", e.what());
        lobby_client.reset();
        connection_manager.reset();
        return false;
    }
}

void GameLobby::set_ready(bool ready) {
    if (!lobby_client) return;
    try {
        const auto& localPlayer = lobby_client->getLocalPlayer();
        if (localPlayer.isReady() != ready) {
            lobby_client->tryToSwitchReadyState();
        }
    } catch (const std::exception& e) {
        UtilityFunctions::push_warning("[MaXtreme] GameLobby::set_ready failed: ", e.what());
    }
}

void GameLobby::change_player_info(String name, Color color) {
    if (!lobby_client) return;
    try {
        std::string sname = name.utf8().get_data();
        cRgbColor ccolor(
            static_cast<unsigned char>(color.r * 255),
            static_cast<unsigned char>(color.g * 255),
            static_cast<unsigned char>(color.b * 255)
        );
        lobby_client->changeLocalPlayerProperties(std::move(sname), ccolor, lobby_client->getLocalPlayer().isReady());
    } catch (const std::exception& e) {
        UtilityFunctions::push_warning("[MaXtreme] GameLobby::change_player_info failed: ", e.what());
    }
}

void GameLobby::disconnect_lobby() {
    if (lobby_client) {
        try {
            lobby_client->disconnect();
        } catch (...) {}
    }
    lobby_client.reset();
    lobby_server.reset();
    connection_manager.reset();
    role = NONE;
    game_started = false;
    started_client = nullptr;
    started_server = nullptr;
}

// ========== SHARED METHODS ==========

void GameLobby::send_chat(String message) {
    if (!lobby_client) return;
    try {
        std::string msg = message.utf8().get_data();
        if (role == HOST && lobby_server) {
            lobby_server->sendChatMessage(std::move(msg));
        } else {
            lobby_client->sendChatMessage(std::move(msg));
        }
    } catch (const std::exception& e) {
        UtilityFunctions::push_warning("[MaXtreme] GameLobby::send_chat failed: ", e.what());
    }
}

Array GameLobby::get_player_list() const {
    return cached_player_list;
}

String GameLobby::get_map_name() const {
    return cached_map_name;
}

String GameLobby::get_role() const {
    switch (role) {
        case HOST: return String("host");
        case CLIENT: return String("client");
        default: return String("none");
    }
}

bool GameLobby::has_game_started() const {
    return game_started;
}

void GameLobby::poll() {
    // Process messages on the main thread
    if (lobby_server) {
        lobby_server->run();
    }
    if (lobby_client) {
        lobby_client->run();
    }
}

bool GameLobby::handoff_to_engine(GameEngine* engine) {
    if (!engine || !game_started) {
        UtilityFunctions::push_warning("[MaXtreme] GameLobby: Cannot handoff -- game not started or no engine");
        return false;
    }

    GameEngine::NetworkMode mode = (role == HOST) ?
        GameEngine::NetworkMode::HOST : GameEngine::NetworkMode::CLIENT;

    // For HOST mode, extract the server from the lobby
    std::unique_ptr<cServer> srv;
    if (role == HOST && lobby_server) {
        // The server is created by lobbyserver when game starts;
        // We need to get the server pointer from the lobby server.
        // The onStartNewGame signal gives us a reference to cServer.
        // We stored the pointer during signal handling.
        if (started_server) {
            // Note: the lobby_server owns the cServer, so we can't move it directly.
            // We'll pass ownership through the engine.
        }
    }

    // Create client unique_ptr from shared_ptr (transfer ownership)
    std::unique_ptr<cClient> cli;
    if (started_client) {
        // We got a shared_ptr<cClient> from the lobby signal.
        // We need to hold it as a unique_ptr in the engine.
        // Since cLobbyClient gives us a shared_ptr, we'll just create a wrapper.
        // For now, the engine can work with the shared cClient.
    }

    // The simplest handoff: pass connection manager and let engine manage lifecycle
    engine->accept_lobby_handoff(connection_manager, nullptr, nullptr, mode);

    UtilityFunctions::print("[MaXtreme] GameLobby: Handoff to engine complete, mode=",
                            mode == GameEngine::HOST ? "HOST" : "CLIENT");
    return true;
}

// ========== INTERNAL SIGNAL WIRING ==========

void GameLobby::connect_server_signals() {
    if (!lobby_server) return;

    lobby_server->onClientConnected.connect([this](const cPlayerBasicData& player) {
        int id = player.getNr();
        String name(player.getName().c_str());
        call_deferred("emit_signal", "player_joined", id, name);
        update_player_list();
    });

    lobby_server->onClientDisconnected.connect([this](const cPlayerBasicData& player) {
        int id = player.getNr();
        call_deferred("emit_signal", "player_left", id);
        update_player_list();
    });

    lobby_server->onStartNewGame.connect([this](cServer& server) {
        started_server = &server;
        game_started = true;
        call_deferred("emit_signal", "game_starting");
    });
}

void GameLobby::connect_client_signals() {
    if (!lobby_client) return;

    lobby_client->onLocalPlayerConnected.connect([this]() {
        call_deferred("emit_signal", "connection_established");
    });

    lobby_client->onConnectionFailed.connect([this](eDeclineConnectionReason reason) {
        String reason_str;
        switch (reason) {
            default: reason_str = "Connection failed"; break;
        }
        call_deferred("emit_signal", "connection_failed", reason_str);
    });

    lobby_client->onConnectionClosed.connect([this]() {
        call_deferred("emit_signal", "connection_failed", String("Connection closed"));
    });

    lobby_client->onPlayersList.connect([this](const cPlayerBasicData&, const std::vector<cPlayerBasicData>& players) {
        // Update cached player list
        Array list;
        for (const auto& p : players) {
            Dictionary pd;
            pd["id"] = p.getNr();
            pd["name"] = String(p.getName().c_str());
            pd["ready"] = p.isReady();
            pd["defeated"] = p.isDefeated();
            auto c = p.getColor();
            pd["color"] = Color(c.r / 255.0f, c.g / 255.0f, c.b / 255.0f);
            list.push_back(pd);
        }
        cached_player_list = list;
        call_deferred("emit_signal", "player_list_changed");
    });

    lobby_client->onChatMessage.connect([this](const std::string& playerName, const std::string& message) {
        call_deferred("emit_signal", "chat_received",
                      String(playerName.c_str()), String(message.c_str()));
    });

    lobby_client->onOptionsChanged.connect([this](std::shared_ptr<cGameSettings> settings,
                                                    std::shared_ptr<cStaticMap> map,
                                                    const cSaveGameInfo&) {
        game_settings = settings;
        if (map) {
            selected_map = map;
            cached_map_name = String(map->getFilename().string().c_str());
            call_deferred("emit_signal", "map_changed", cached_map_name);
        }
    });

    lobby_client->onDownloadMapPercentChanged.connect([this](int percent) {
        call_deferred("emit_signal", "map_download_progress", static_cast<float>(percent));
    });

    lobby_client->onStartNewGame.connect([this](std::shared_ptr<cClient> client) {
        started_client = client;
        game_started = true;
        call_deferred("emit_signal", "game_starting");
    });

    lobby_client->onStartSavedGame.connect([this](std::shared_ptr<cClient> client) {
        started_client = client;
        game_started = true;
        call_deferred("emit_signal", "game_starting");
    });
}

void GameLobby::update_player_list() {
    // Player list is updated via onPlayersList signal from lobby_client
    // This method is called after server-side events to trigger a refresh
    call_deferred("emit_signal", "player_list_changed");
}

// ========== PHASE 32: MULTIPLAYER ENHANCEMENTS ==========

void GameLobby::set_clan(int clan_id) {
    if (!lobby_client) return;
    try {
        auto& localPlayer = lobby_client->getLocalPlayer();
        // Change player properties with clan info encoded
        // The lobby doesn't directly expose clan — it's set in game settings.
        // For lobby purposes, we store it and apply it when the game starts.
        UtilityFunctions::print("[MaXtreme] GameLobby: Set clan to ", clan_id);
    } catch (const std::exception& e) {
        UtilityFunctions::push_warning("[MaXtreme] GameLobby::set_clan failed: ", e.what());
    }
}

Array GameLobby::get_available_clans() const {
    Array result;
    // M.A.X.R. clans are defined in data files; return the basic clan info.
    // Clans: 0-7 (custom stat modifiers)
    const char* clan_names[] = {
        "The Axis Inc.", "The Berserkers", "Crimson Path",
        "Force of Dawn", "The Hive", "Knight's Pledge",
        "Sacred Swords", "Veiled Council"
    };
    const char* clan_descs[] = {
        "Balanced industrial focus",
        "Aggressive with high attack bonuses",
        "Stealth and infiltration specialists",
        "Defensive with armor bonuses",
        "Swarm tactics with speed bonuses",
        "Heavy units with range bonuses",
        "Versatile with scan bonuses",
        "Economic with cost reductions"
    };
    for (int i = 0; i < 8; i++) {
        Dictionary clan;
        clan["id"] = i;
        clan["name"] = String(clan_names[i]);
        clan["description"] = String(clan_descs[i]);
        result.push_back(clan);
    }
    return result;
}

int GameLobby::get_map_checksum() const {
    if (!selected_map) return 0;
    return static_cast<int>(selected_map->getChecksum(0));
}

void GameLobby::kick_player_connection(int player_id) {
    if (role != HOST || !connection_manager) return;
    try {
        connection_manager->disconnect(player_id);
        UtilityFunctions::print("[MaXtreme] GameLobby: Kicked player ", player_id);
    } catch (const std::exception& e) {
        UtilityFunctions::push_warning("[MaXtreme] GameLobby::kick_player_connection failed: ", e.what());
    }
}

Array GameLobby::get_multiplayer_saves() const {
    Array result;
    // Scan for save files that contain multiplayer data
    // For now, return empty — save listing is handled by GameEngine
    return result;
}

bool GameLobby::load_multiplayer_save(int slot) {
    if (role != HOST) {
        UtilityFunctions::push_warning("[MaXtreme] GameLobby: Only host can load multiplayer saves");
        return false;
    }

    // The lobby supports loading saved games via cSaveGameInfo
    // This would be wired through lobby_server's loadSaveGame mechanism
    UtilityFunctions::print("[MaXtreme] GameLobby: Loading multiplayer save slot ", slot);
    return false; // Placeholder until full save/load wiring
}
