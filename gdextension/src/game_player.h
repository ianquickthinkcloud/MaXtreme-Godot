#ifndef MAXTREME_GAME_PLAYER_H
#define MAXTREME_GAME_PLAYER_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/vector2i.hpp>

#include <memory>

class cPlayer;

namespace godot {

/// GamePlayer - GDScript wrapper around M.A.X.R.'s cPlayer.
/// Exposes player identity, resources, research, economy, and unit counts to Godot.
class GamePlayer : public RefCounted {
    GDCLASS(GamePlayer, RefCounted)

private:
    std::shared_ptr<cPlayer> player;

protected:
    static void _bind_methods();

public:
    GamePlayer();
    ~GamePlayer();

    // Internal: set the wrapped cPlayer (called from C++ only)
    void set_internal_player(std::shared_ptr<cPlayer> p);

    // --- Identity ---
    String get_name() const;
    int get_id() const;
    Color get_color() const;
    int get_clan() const;

    // --- Economy ---
    int get_credits() const;
    int get_score() const;

    // --- Unit counts ---
    int get_vehicle_count() const;
    int get_building_count() const;

    // --- Research ---
    int get_research_centers_working() const;

    // --- Game state ---
    bool is_defeated() const;
    bool has_finished_turn() const;

    // --- Statistics ---
    int get_built_vehicles_count() const;
    int get_lost_vehicles_count() const;
    int get_built_buildings_count() const;
    int get_lost_buildings_count() const;

    // ========== BASE RESOURCE STORAGE (Phase 8) ==========

    /// Returns {metal, oil, gold, metal_max, oil_max, gold_max}
    /// Summed across all sub-bases.
    Dictionary get_resource_storage() const;

    /// Returns {metal, oil, gold} per-turn production across all sub-bases.
    Dictionary get_resource_production() const;

    /// Returns {metal, oil, gold} per-turn consumption across all sub-bases.
    Dictionary get_resource_needed() const;

    // ========== ENERGY BALANCE ==========

    /// Returns {production, need, max_production, max_need}
    Dictionary get_energy_balance() const;

    // ========== HUMAN BALANCE ==========

    /// Returns {production, need, max_need}
    Dictionary get_human_balance() const;

    // ========== RESEARCH STATE ==========

    /// Returns research levels per area:
    /// {attack, shots, range, armor, hitpoints, speed, scan, cost} (0/10/20/30...)
    Dictionary get_research_levels() const;

    /// Returns 8-element Array of how many centers work on each area
    Array get_research_centers_per_area() const;

    // ========== SUMMARY ==========

    /// Convenience: all economy info in one dictionary
    Dictionary get_economy_summary() const;

    // ========== FOG OF WAR / VISIBILITY (Phase 14) ==========

    /// Returns true if the player can currently see the given tile position
    /// (i.e. tile is within scan range of any of this player's units).
    bool can_see_at(Vector2i pos) const;

    /// Returns the raw scan map as a PackedInt32Array (width * height elements).
    /// Each value > 0 means the tile is currently visible to this player.
    /// Layout is row-major: index = y * width + x.
    PackedInt32Array get_scan_map_data() const;

    /// Returns the map dimensions for interpreting scan map data.
    Vector2i get_scan_map_size() const;
};

} // namespace godot

#endif // MAXTREME_GAME_PLAYER_H
