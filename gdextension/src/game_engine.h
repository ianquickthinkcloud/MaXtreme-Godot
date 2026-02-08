#ifndef MAXTREME_GAME_ENGINE_H
#define MAXTREME_GAME_ENGINE_H

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/array.hpp>

#include <memory>

// Forward declarations of M.A.X.R. core types
class cModel;
class cUnitsData;
class cServer;
class cClient;
class cConnectionManager;

// Forward declarations of wrapper types
namespace godot {
class GameMap;
class GamePlayer;
class GameUnit;
class GameActions;
class GameSetup;
class GamePathfinder;
class GameLobby;
}

namespace godot {

/// GameEngine - The main bridge between Godot and the M.A.X.R. C++ engine.
///
/// Supports three modes:
///   SINGLE_PLAYER - direct model manipulation (original behavior)
///   HOST          - owns a cServer with authoritative model + lockstep timer
///   CLIENT        - owns a cClient with local model synced from server
class GameEngine : public Node {
    GDCLASS(GameEngine, Node)

public:
    enum NetworkMode { SINGLE_PLAYER = 0, HOST = 1, CLIENT = 2 };

private:
    bool engine_initialized = false;
    NetworkMode network_mode = SINGLE_PLAYER;

    // Single-player: direct model ownership
    std::unique_ptr<cModel> model;
    std::shared_ptr<cUnitsData> unitsData;

    // Multiplayer: server/client + shared connection manager
    std::shared_ptr<cConnectionManager> connection_manager;
    std::unique_ptr<cServer> server;    // HOST mode only
    std::unique_ptr<cClient> client;    // CLIENT mode only (also created for HOST)

    /// Returns the active cModel* regardless of mode.
    cModel* get_active_model() const;

protected:
    static void _bind_methods();

public:
    GameEngine();
    ~GameEngine();

    // --- Lifecycle ---
    String get_engine_version() const;
    String get_engine_status() const;
    bool is_engine_initialized() const;
    void initialize_engine();

    // --- Game state ---
    int get_turn_number() const;
    int get_player_count() const;

    // --- Map access ---
    Ref<GameMap> get_map() const;
    String get_map_name() const;

    // --- Player access ---
    Ref<GamePlayer> get_player(int index) const;
    Array get_all_players() const;

    // --- Unit access ---
    Ref<GameUnit> get_unit_by_id(int player_index, int unit_id) const;
    Array get_player_vehicles(int player_index) const;
    Array get_player_buildings(int player_index) const;

    // --- Action system ---
    Ref<GameActions> get_actions() const;

    // --- Pathfinding (Phase 7) ---
    Ref<GamePathfinder> get_pathfinder() const;

    // --- Data loading (Phase 8) ---

    /// Load game data (vehicles, buildings, clans) from JSON files.
    /// Safe to call multiple times - data is only loaded once.
    /// Returns true if data loaded successfully.
    bool load_game_data();

    /// Get list of available map filenames from data/maps/
    Array get_available_maps() const;

    /// Get list of available clans (Array of Dictionaries with name, description, index)
    Array get_available_clans() const;

    /// Get info about loaded unit data (vehicle/building counts, names, etc.)
    Dictionary get_unit_data_info() const;

    // --- Phase 18: Pre-game setup data ---

    /// Get all purchasable vehicle types for the unit purchase screen.
    /// clan: -1 for base stats, 0-7 for clan-modified stats.
    Array get_purchasable_vehicles(int clan) const;

    /// Get free initial landing units for a given bridgehead type.
    Array get_initial_landing_units(int clan, int start_credits, String bridgehead_type) const;

    /// Get detailed clan info with stat modifications.
    Array get_clan_details() const;

    /// Check if a position is valid for landing on a given map.
    bool check_landing_position(String map_name, Vector2i pos) const;

    // --- Phase 21: Pre-game upgrade info ---

    /// Get upgrade info for all unit types at research level 0 (for pre-game purchasing).
    /// Returns Array of Dicts: [{id_first, id_second, name, build_cost,
    ///   upgrades: [{index, type, cur_value, next_price, purchased}]}]
    Array get_pregame_upgrade_info(int clan) const;

    // --- Game initialization (Phase 4, updated Phase 8) ---

    /// Start a quick test game using real data: first available map, 2 players,
    /// 150 credits each, starting units from loaded data.
    /// Returns a Dictionary with game details on success.
    Dictionary new_game_test();

    /// Start a custom game with specified parameters.
    /// map_name: String map filename (e.g. "Delta.wrl"), or "" for auto-select
    /// player_names: Array of String
    /// player_colors: Array of Color
    /// player_clans: Array of int (-1 = no clan, 0-7 = clan index)
    /// start_credits: int
    /// Returns a Dictionary with game details on success.
    Dictionary new_game(String map_name, Array player_names, Array player_colors, Array player_clans, int start_credits);

    /// Start a custom game with full game settings Dictionary.
    /// See GameSetup::setup_custom_game_ex for the full list of keys.
    /// Returns a Dictionary with game details on success.
    Dictionary new_game_ex(Dictionary game_settings);

    // --- Save/Load (Phase 13) ---

    /// Save the current game to a slot (1-100). Returns true on success.
    bool save_game(int slot, String save_name);

    /// Load a game from a slot. Returns a Dictionary with game details on success.
    Dictionary load_game(int slot);

    /// Get a list of save game slots with info. Returns Array of Dictionaries.
    /// Each dict: {slot, name, date, turn, map, players: [{name, id, defeated}]}
    Array get_save_game_list();

    /// Get info for a specific save slot. Returns a Dictionary (empty if slot not found).
    Dictionary get_save_game_info(int slot);

    // --- Networking (Phase 16) ---

    /// Set up as host: creates cConnectionManager, cServer, cClient (local).
    /// Called by GameLobby when the lobby transitions to a game.
    /// port: TCP port the server listens on.
    bool setup_as_host(int port);

    /// Set up as client: receives a cConnectionManager and creates cClient.
    /// Called by GameLobby when the lobby transitions to a game.
    bool setup_as_client();

    /// Accept the connection manager and server/client from a GameLobby.
    /// This is the primary handoff mechanism from the lobby to the game.
    void accept_lobby_handoff(std::shared_ptr<cConnectionManager> conn_mgr,
                              std::unique_ptr<cServer> srv,
                              std::unique_ptr<cClient> cli,
                              NetworkMode mode);

    /// Get the current network mode as a string: "single_player", "host", "client"
    String get_network_mode() const;

    /// Returns true if in HOST or CLIENT mode.
    bool is_multiplayer() const;

    /// Get the cClient pointer (for GameActions routing in multiplayer).
    cClient* get_client() const;

    // --- Turn System & Game Loop (Phase 5) ---

    /// Advance game time by one tick (10ms of game time).
    /// In multiplayer mode, this is a no-op (lockstep timer handles ticks).
    void advance_tick();

    /// Advance game time by N ticks.
    /// Useful for fast-forwarding or processing a batch of ticks per frame.
    void advance_ticks(int count);

    /// Get the current game time (in ticks, each tick = 10ms).
    int get_game_time() const;

    /// Mark a player as having finished their turn.
    /// In simultaneous mode, the turn advances when ALL players finish.
    /// Returns true if the player was found and marked.
    bool end_player_turn(int player_id);

    /// Signal a player that their turn has started (needed for hot-seat mode).
    /// Returns true if the player was found.
    bool start_player_turn(int player_id);

    /// Check if a turn is currently active (players are giving orders).
    /// Returns false if the engine is processing end-of-turn movements or turn transitions.
    bool is_turn_active() const;

    /// Check if all players have finished their turn.
    bool all_players_finished() const;

    /// Get the current turn state as a string: "active", "executing_moves", "turn_start".
    String get_turn_state() const;

    /// Get a comprehensive game state Dictionary with turn, time, player states.
    Dictionary get_game_state() const;

    /// Process the game loop: advance ticks until an interesting event happens
    /// or max_ticks is reached. Returns a Dictionary with what happened.
    /// This is the main function GDScript should call each frame.
    Dictionary process_game_tick();

    // --- Phase 20: Turn Timer & Victory ---

    /// Returns time remaining until turn deadline in seconds.
    /// Returns -1.0 if no deadline is active.
    double get_turn_time_remaining() const;

    /// Returns true if a turn deadline is configured and active.
    bool has_turn_deadline() const;

    /// Returns true if the victory condition has been met.
    /// The specific condition depends on game settings (Elimination, Turn Limit, Points).
    bool is_victory_condition_met() const;

    /// Returns the victory type as a string: "none", "elimination", "turn_limit", "points"
    String get_victory_type() const;
};

} // namespace godot

#endif // MAXTREME_GAME_ENGINE_H
