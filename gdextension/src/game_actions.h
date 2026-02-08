#ifndef MAXTREME_GAME_ACTIONS_H
#define MAXTREME_GAME_ACTIONS_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/vector2i.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>

#include <memory>

class cModel;
class cClient;
class cUnit;
class cVehicle;
class cBuilding;
class cPlayer;

namespace godot {

/// GameActions - Command factory and executor for the M.A.X.R. action system.
///
/// This is the core of gameplay. Each method creates the appropriate cAction
/// and executes it directly on the cModel. Actions are validated internally
/// by the engine (same checks as multiplayer) so invalid commands are safely rejected.
///
/// Usage from GDScript:
///   var actions = engine.get_actions()
///   actions.move_unit(unit_id, path)
///   actions.attack(attacker_id, target_pos)
///   actions.end_turn()
class GameActions : public RefCounted {
    GDCLASS(GameActions, RefCounted)

private:
    cModel* model = nullptr;    // Non-owning: lifetime managed by GameEngine
    cClient* client = nullptr;  // Non-owning: set in multiplayer mode for action routing

    // Helper: find a unit across all players
    cUnit* find_unit(int unit_id) const;
    cVehicle* find_vehicle(int unit_id) const;
    cBuilding* find_building(int unit_id) const;
    cPlayer* find_unit_owner(int unit_id) const;

protected:
    static void _bind_methods();

public:
    GameActions();
    ~GameActions();

    // Internal: bind to the model (called from C++ only)
    void set_internal_model(cModel* m);

    // Internal: bind to the cClient for multiplayer action routing.
    // When client is set, actions route through the network instead of executing locally.
    void set_internal_client(cClient* c);

    // ========== MOVEMENT ==========

    /// Move a unit along a path (array of Vector2i waypoints).
    /// Returns true if the move action was created successfully.
    bool move_unit(int unit_id, PackedVector2Array path);

    /// Resume a paused move for a vehicle.
    bool resume_move(int unit_id);

    /// Set auto-move on/off for a surveyor or similar unit.
    bool set_auto_move(int unit_id, bool enabled);

    // ========== COMBAT ==========

    /// Attack a target position. If target_unit_id is -1, it's a ground attack.
    bool attack(int attacker_id, Vector2i target_pos, int target_unit_id = -1);

    /// Toggle sentry mode on a unit.
    bool toggle_sentry(int unit_id);

    /// Toggle manual fire mode on a unit.
    bool toggle_manual_fire(int unit_id);

    /// Set mine layer status (lay mines, clear mines).
    bool set_minelayer_status(int unit_id, bool lay_mines, bool clear_mines);

    // ========== CONSTRUCTION ==========

    /// Start building a structure. building_type_id is the sID as "firstPart.secondPart" string.
    bool start_build(int vehicle_id, String building_type_id, int build_speed, Vector2i build_pos);

    /// Finish a build (vehicle exits to escape position after building completes).
    bool finish_build(int unit_id, Vector2i escape_pos);

    /// Change a factory's build list. build_list is an Array of type ID strings.
    bool change_build_list(int building_id, Array build_list, int build_speed, bool repeat);

    // ========== PRODUCTION & WORK ==========

    /// Start work on a building (factory producing, research lab researching, etc.)
    bool start_work(int unit_id);

    /// Stop the current work/action on a unit.
    bool stop(int unit_id);

    /// Set resource distribution for a mining station.
    bool set_resource_distribution(int building_id, int metal, int oil, int gold);

    /// Change research allocation. areas is an array of 8 ints (center counts per area).
    bool change_research(Array areas);

    // ========== LOGISTICS ==========

    /// Transfer resources between two adjacent units.
    bool transfer_resources(int source_id, int dest_id, int amount, String resource_type);

    /// Load a vehicle into a transport/building.
    bool load_unit(int loader_id, int vehicle_id);

    /// Activate (unload) a stored vehicle to a position.
    bool activate_unit(int container_id, int vehicle_id, Vector2i position);

    /// Repair or reload a unit from a supply unit.
    bool repair_reload(int source_id, int target_id, String supply_type);

    // ========== SPECIAL ==========

    /// Commando steal or disable action.
    bool steal_disable(int infiltrator_id, int target_id, bool steal);

    /// Clear rubble with an engineer vehicle.
    bool clear_area(int vehicle_id);

    /// Self-destruct a building.
    bool self_destroy(int building_id);

    /// Rename a unit.
    bool rename_unit(int unit_id, String new_name);

    /// Upgrade a vehicle at a depot.
    bool upgrade_vehicle(int building_id, int vehicle_id);

    /// Upgrade a building (or all buildings of same type if all=true).
    bool upgrade_building(int building_id, bool all);

    // ========== GOLD UPGRADES (Phase 21) ==========

    /// Returns all unit types that can be upgraded with gold, along with their
    /// current upgrade state. Each element is a Dictionary:
    ///   {id_first, id_second, name, build_cost,
    ///    upgrades: [{type, start_value, cur_value, next_price, purchased}]}
    /// stat types: 0=Damage, 1=Shots, 2=Range, 3=Ammo, 4=Armor, 5=Hits, 6=Scan, 7=Speed
    Array get_upgradeable_units(int player_id);

    /// Purchase a single stat upgrade for a unit type.
    /// stat_index: 0=Damage, 1=Shots, 2=Range, 3=Ammo, 4=Armor, 5=Hits, 6=Scan, 7=Speed
    /// Returns the cost deducted (> 0), or -1 on failure.
    int buy_unit_upgrade(int player_id, int id_first, int id_second, int stat_index);

    /// Get the metal cost to upgrade a specific vehicle to the latest version.
    /// Returns -1 if the vehicle cannot be upgraded (already at latest version).
    int get_vehicle_upgrade_cost(int vehicle_id);

    /// Get the metal cost to upgrade a specific building to the latest version.
    /// Returns -1 if the building cannot be upgraded (already at latest version).
    int get_building_upgrade_cost(int building_id);

    // ========== TURN MANAGEMENT ==========

    /// End the current player's turn.
    bool end_turn();

    /// Start a new turn (server-side).
    bool start_turn();
};

} // namespace godot

#endif // MAXTREME_GAME_ACTIONS_H
