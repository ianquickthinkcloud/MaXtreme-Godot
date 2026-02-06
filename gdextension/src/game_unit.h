#ifndef MAXTREME_GAME_UNIT_H
#define MAXTREME_GAME_UNIT_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/vector2i.hpp>
#include <godot_cpp/variant/dictionary.hpp>

class cUnit;
class cVehicle;
class cBuilding;

namespace godot {

/// GameUnit - GDScript wrapper around M.A.X.R.'s cUnit (cVehicle / cBuilding).
/// Exposes unit identity, position, stats, and state to Godot.
class GameUnit : public RefCounted {
    GDCLASS(GameUnit, RefCounted)

private:
    cUnit* unit = nullptr;  // Non-owning pointer (owned by cPlayer)

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
};

} // namespace godot

#endif // MAXTREME_GAME_UNIT_H
