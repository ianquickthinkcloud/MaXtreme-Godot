#ifndef MAXTREME_GAME_PLAYER_H
#define MAXTREME_GAME_PLAYER_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/array.hpp>

#include <memory>

class cPlayer;

namespace godot {

/// GamePlayer - GDScript wrapper around M.A.X.R.'s cPlayer.
/// Exposes player identity, resources, research, and unit counts to Godot.
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
};

} // namespace godot

#endif // MAXTREME_GAME_PLAYER_H
