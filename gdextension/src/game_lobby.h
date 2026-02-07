#ifndef MAXTREME_GAME_LOBBY_H
#define MAXTREME_GAME_LOBBY_H

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/color.hpp>

#include <memory>

// Forward declarations of M.A.X.R. types
class cConnectionManager;
class cLobbyServer;
class cLobbyClient;
class cServer;
class cClient;
class cPlayerBasicData;
class cStaticMap;
class cGameSettings;
class cSaveGameInfo;

namespace godot {

class GameEngine;

/// GameLobby -- GDExtension wrapper around cLobbyServer/cLobbyClient.
///
/// Manages the multiplayer lobby: hosting, joining, player management,
/// map selection, chat, and transitioning to the game.
///
/// Usage:
///   var lobby = GameLobby.new()
///   add_child(lobby)
///   lobby.host_game(58600)       # or lobby.join_game("192.168.1.5", 58600, "Player", Color.RED)
///   lobby.poll()                  # call from _process()
class GameLobby : public Node {
    GDCLASS(GameLobby, Node)

public:
    enum Role { NONE = 0, HOST = 1, CLIENT = 2 };

private:
    Role role = NONE;
    std::shared_ptr<cConnectionManager> connection_manager;
    std::unique_ptr<cLobbyServer> lobby_server;  // HOST only
    std::unique_ptr<cLobbyClient> lobby_client;  // Both HOST and CLIENT
    std::shared_ptr<cStaticMap> selected_map;
    std::shared_ptr<cGameSettings> game_settings;

    // Cached player list for GDScript access
    Array cached_player_list;
    String cached_map_name;
    bool game_started = false;

    // Client received from lobby on game start
    std::shared_ptr<cClient> started_client;
    // Server received from lobby on game start (host only)
    cServer* started_server = nullptr;

    // Connect internal M.A.X.R. signals to Godot signals
    void connect_server_signals();
    void connect_client_signals();
    void update_player_list();

protected:
    static void _bind_methods();

public:
    GameLobby();
    ~GameLobby();

    // --- Host-side methods ---

    /// Host a game on the specified TCP port.
    bool host_game(int port, String player_name, Color player_color);

    /// Select a map for the game (host only).
    bool select_map(String map_name);

    /// Kick a player from the lobby (host only).
    void kick_player(int player_id);

    /// Signal to start the game (host only).
    bool start_game();

    // --- Client-side methods ---

    /// Join a game at the specified host and port.
    bool join_game(String host, int port, String player_name, Color player_color);

    /// Toggle ready state (client only).
    void set_ready(bool ready);

    /// Change local player info.
    void change_player_info(String name, Color color);

    /// Disconnect from the lobby.
    void disconnect_lobby();

    // --- Shared methods ---

    /// Send a chat message.
    void send_chat(String message);

    /// Get the current player list as an Array of Dictionaries.
    Array get_player_list() const;

    /// Get the currently selected map name.
    String get_map_name() const;

    /// Get the lobby role as a string: "none", "host", "client".
    String get_role() const;

    /// Has the game started (lobby finished)?
    bool has_game_started() const;

    /// Process the network message queue. Call from _process().
    void poll();

    /// Hand off the server/client to a GameEngine for gameplay.
    /// Returns true if handoff succeeded.
    bool handoff_to_engine(GameEngine* engine);
};

} // namespace godot

#endif // MAXTREME_GAME_LOBBY_H
