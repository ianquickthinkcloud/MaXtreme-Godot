#ifndef MAXTREME_GAME_UNIT_H
#define MAXTREME_GAME_UNIT_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/vector2i.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/array.hpp>

class cUnit;
class cVehicle;
class cBuilding;

namespace godot {

/// GameUnit - GDScript wrapper around M.A.X.R.'s cUnit (cVehicle / cBuilding).
/// Exposes unit identity, position, stats, state, and building/production data to Godot.
class GameUnit : public RefCounted {
    GDCLASS(GameUnit, RefCounted)

private:
    cUnit* unit = nullptr;  // Non-owning pointer (owned by cPlayer)

    // Internal helpers for casting
    cBuilding* as_building() const;
    cVehicle* as_vehicle() const;

protected:
    static void _bind_methods();

public:
    GameUnit();
    ~GameUnit();

    // Internal: set the wrapped cUnit (called from C++ only)
    void set_internal_unit(cUnit* u);

    // --- Identity ---
    int get_id() const;
    String get_name() const;
    String get_type_name() const;
    String get_description() const;
    bool is_vehicle() const;
    bool is_building() const;

    // --- Position ---
    Vector2i get_position() const;
    bool is_big() const;  // occupies 2x2 tiles

    // --- Core stats (dynamic, may be upgraded) ---
    int get_hitpoints() const;
    int get_hitpoints_max() const;
    int get_armor() const;
    int get_damage() const;
    int get_speed() const;
    int get_speed_max() const;
    int get_scan() const;
    int get_range() const;
    int get_shots() const;
    int get_shots_max() const;
    int get_ammo() const;
    int get_ammo_max() const;
    int get_build_cost() const;

    // --- Combat capability (static data) ---
    int get_can_attack() const;         // bitfield: Air=1, Sea=2, Ground=4, Coast=8
    bool can_attack_air() const;
    bool can_attack_ground() const;
    bool can_attack_sea() const;
    bool has_weapon() const;            // true if canAttack != 0
    String get_muzzle_type() const;     // "Big", "Small", "Rocket", etc.
    int calc_damage_to(int target_armor) const;  // Preview damage: max(1, damage - armor)
    bool is_in_range_of(Vector2i target_pos) const;  // Range check

    // --- State ---
    bool is_disabled() const;
    int get_disabled_turns() const;
    bool is_sentry_active() const;
    bool is_manual_fire() const;
    bool is_attacking() const;
    bool is_being_attacked() const;
    int get_stored_resources() const;
    int get_stored_units_count() const;

    // --- Owner ---
    int get_owner_id() const;

    // --- Full stats as a dictionary (convenient for UI) ---
    Dictionary get_stats() const;

    // --- Experience & version (Phase 20) ---
    /// Returns the commando rank level (0-5). Returns -1 for non-commando units.
    int get_commando_rank() const;

    /// Returns the commando rank name ("Greenhorn", "Average", etc.)
    /// Returns "" for non-commando units.
    String get_commando_rank_name() const;

    /// Returns true if this unit's stats are outdated compared to the player's
    /// latest research version of this unit type.
    bool is_dated() const;

    /// Returns the unit's current version number.
    int get_version() const;

    // --- Capability flags (from static data) ---
    /// Returns a Dictionary of boolean capability flags for the selected unit.
    /// Keys: has_weapon, can_survey, can_place_mines, can_clear_area,
    ///       can_capture, can_disable, can_repair, can_rearm,
    ///       can_self_destroy, can_store_units, can_store_resources,
    ///       is_stealth, storage_units_max, storage_res_max
    Dictionary get_capabilities() const;

    // --- Stored units (cargo) ---
    /// Returns Array of Dictionaries for all units stored inside this unit.
    /// Each dict: {id, name, type_name, hp, hp_max}
    Array get_stored_units() const;

    // ========== CONSTRUCTION CAPABILITY (vehicles) ==========

    /// Returns the canBuild string from static data (e.g. "big,small", "BigBuilding")
    /// Empty string if this unit cannot build.
    String get_can_build() const;

    /// Returns true if this vehicle is a Constructor (can build buildings)
    bool is_constructor() const;

    /// Returns Array of Dictionaries describing buildings this Constructor can build.
    /// Each dict: {id: "1.5", name: "Small Generator", cost: 4, is_big: false}
    Array get_buildable_types() const;

    /// Returns true if vehicle is currently constructing a building
    bool is_building_a_building() const;

    /// Returns how many build turns remain (for a vehicle building)
    int get_build_turns_remaining() const;

    /// Returns remaining build cost (metal) for current construction
    int get_build_costs_remaining() const;

    /// Returns total build cost (metal) for current construction start
    int get_build_costs_start() const;

    // ========== BUILDING PRODUCTION STATE ==========

    /// Returns true if the building is currently working (producing/researching/mining)
    bool is_working() const;

    /// Returns true if the building can be started (has build list, resources, etc.)
    bool can_start_work() const;

    /// Returns number of items in the factory's build queue
    int get_build_list_size() const;

    /// Returns the factory build queue as Array of Dictionaries.
    /// Each dict: {type_id: "0.1", type_name: "Tank", remaining_metal: 6, total_cost: 12}
    Array get_build_list() const;

    /// Returns Array of Dictionaries for units this factory can produce.
    /// Each dict: {id: "0.1", name: "Tank", cost: 12}
    Array get_producible_types() const;

    /// Returns current build speed (1, 2, or 4 for turbo)
    int get_build_speed() const;

    /// Returns metal consumed per round at current build speed
    int get_metal_per_round() const;

    /// Returns true if repeat build is enabled
    bool get_repeat_build() const;

    // ========== BUILDING MINING STATE ==========

    /// Returns current mining production as Dictionary {metal: X, oil: Y, gold: Z}
    Dictionary get_mining_production() const;

    /// Returns max possible mining production as Dictionary {metal: X, oil: Y, gold: Z}
    Dictionary get_mining_max() const;

    // ========== BUILDING RESEARCH STATE ==========

    /// Returns the research area index (0-7) this lab is researching.
    /// -1 if not a research building.
    int get_research_area() const;

    // ========== BUILDING UPGRADE STATE ==========

    /// Returns true if this building can be upgraded
    bool can_be_upgraded() const;

    /// Returns true if building connects to base network
    bool connects_to_base() const;

    /// Returns energy produced by this building (0 if not a generator)
    int get_energy_production() const;

    /// Returns energy needed by this building
    int get_energy_need() const;

    // ========== PHASE 26: CONSTRUCTION ENHANCEMENTS ==========

    /// For vehicles: returns turbo build info for a building type as Dictionary.
    /// {turns_0, cost_0, turns_1, cost_1, turns_2, cost_2}
    /// Speeds: 0=normal, 1=2x, 2=4x. Cost/turns=0 if speed not available.
    Dictionary get_turbo_build_info(String building_type_id) const;

    /// Returns true if this vehicle can build roads/bridges/platforms (path building).
    bool can_build_path() const;

    /// For buildings: returns connection flags as Dictionary.
    /// {BaseN, BaseE, BaseS, BaseW, BaseBN, BaseBE, BaseBS, BaseBW, connects_to_base}
    Dictionary get_connection_flags() const;

    /// Returns max build factor (0 = no turbo, >1 means turbo build is available)
    int get_max_build_factor() const;
};

} // namespace godot

#endif // MAXTREME_GAME_UNIT_H
