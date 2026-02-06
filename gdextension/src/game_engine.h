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
};

} // namespace godot

#endif // MAXTREME_GAME_ENGINE_H
