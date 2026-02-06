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

// Forward declarations of wrapper types
namespace godot {
class GameMap;
class GamePlayer;
class GameUnit;
class GameActions;
class GameSetup;
class GamePathfinder;
}

namespace godot {

/// GameEngine - The main bridge between Godot and the M.A.X.R. C++ engine.
///
/// Phase 2: Full data bridge. Exposes cModel, cMap, cPlayer, and cUnit data
/// to GDScript via GameMap, GamePlayer, and GameUnit wrapper objects.
class GameEngine : public Node {
    GDCLASS(GameEngine, Node)

private:
    bool engine_initialized = false;
    std::unique_ptr<cModel> model;
    std::shared_ptr<cUnitsData> unitsData;

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

    // --- Game initialization (Phase 4) ---

    /// Start a quick test game: 64x64 map, 2 players, 150 credits each,
    /// 4 starting units per player (Constructor, 2x Tank, Surveyor).
    /// Returns a Dictionary with game details on success.
    Dictionary new_game_test();

    /// Start a custom game with specified parameters.
    /// player_names: Array of String
    /// player_colors: Array of Color
    /// map_size: int (power of 2, e.g. 32, 64, 128)
    /// start_credits: int
    /// Returns a Dictionary with game details on success.
    Dictionary new_game(Array player_names, Array player_colors, int map_size, int start_credits);

    // --- Turn System & Game Loop (Phase 5) ---

    /// Advance game time by one tick (10ms of game time).
    /// Processes move jobs, attack jobs, effects, and turn-end logic.
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
};

} // namespace godot

#endif // MAXTREME_GAME_ENGINE_H
