#ifndef GAME_PATHFINDER_H
#define GAME_PATHFINDER_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/vector2i.hpp>

class cModel;

namespace godot {

class GamePathfinder : public RefCounted {
    GDCLASS(GamePathfinder, RefCounted)

private:
    cModel* model = nullptr;

protected:
    static void _bind_methods();

public:
    GamePathfinder();
    ~GamePathfinder();

    void set_internal_model(cModel* m);

    // --- Path calculation ---

    /// Calculate an A* path from the unit's current position to the target.
    /// Returns a PackedVector2Array of tile positions (empty if no path).
    PackedVector2Array calculate_path(int unit_id, Vector2i target) const;

    /// Get the total movement cost of a given path for a unit.
    /// Returns -1 if invalid.
    int get_path_cost(int unit_id, PackedVector2Array path) const;

    /// Get the movement cost from one tile to an adjacent tile for a unit.
    int get_step_cost(int unit_id, Vector2i from, Vector2i to) const;

    // --- Movement range ---

    /// Calculate all tiles reachable by a unit given its current movement points.
    /// Returns an Array of Dictionaries: [{"pos": Vector2i, "cost": int}, ...]
    Array get_reachable_tiles(int unit_id) const;

    /// Get a PackedVector2Array of just the reachable positions (no cost info).
    PackedVector2Array get_reachable_positions(int unit_id) const;

    /// Check if a specific tile is reachable by a unit this turn.
    bool is_tile_reachable(int unit_id, Vector2i target) const;

    // --- Attack range ---

    /// Get all enemy units within attack range of a unit.
    /// Returns Array of Dictionaries: [{"id": int, "pos": Vector2i, "owner": int, "distance": int}, ...]
    Array get_enemies_in_range(int unit_id) const;

    /// Get tiles within attack range as a PackedVector2Array.
    PackedVector2Array get_attack_range_tiles(int unit_id) const;

    /// Check if a unit can attack a specific position (has weapon, shots, ammo, in range).
    bool can_attack_position(int unit_id, Vector2i target) const;

    /// Preview damage: returns how much damage unit_id would deal to target_unit_id.
    /// Returns a Dictionary: {"damage": int, "target_hp_after": int, "will_destroy": bool}
    Dictionary preview_attack(int attacker_id, int target_id) const;

    // --- Utility ---

    /// Get the unit's current available movement points.
    int get_movement_points(int unit_id) const;

    /// Get the unit's maximum movement points.
    int get_movement_points_max(int unit_id) const;
};

} // namespace godot

#endif // GAME_PATHFINDER_H
