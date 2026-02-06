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
};

} // namespace godot

#endif // MAXTREME_GAME_ENGINE_H
