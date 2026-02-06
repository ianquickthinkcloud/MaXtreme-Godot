#ifndef MAXTREME_GAME_MAP_H
#define MAXTREME_GAME_MAP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/vector2i.hpp>
#include <godot_cpp/variant/dictionary.hpp>

#include <memory>

class cMap;
class cStaticMap;

namespace godot {

/// GameMap - GDScript wrapper around M.A.X.R.'s cMap / cStaticMap.
/// Exposes map geometry, terrain queries, and resource data to Godot.
class GameMap : public RefCounted {
    GDCLASS(GameMap, RefCounted)

private:
    std::shared_ptr<cMap> map;

protected:
    static void _bind_methods();

public:
    GameMap();
    ~GameMap();

    // Internal: set the wrapped cMap (called from C++ only, not bound to GDScript)
    void set_internal_map(std::shared_ptr<cMap> m);

    // --- Map geometry ---
    Vector2i get_size() const;
    int get_width() const;
    int get_height() const;
    bool is_valid_position(Vector2i pos) const;

    // --- Terrain queries ---
    bool is_water(Vector2i pos) const;
    bool is_coast(Vector2i pos) const;
    bool is_blocked(Vector2i pos) const;
    bool is_ground(Vector2i pos) const;

    // --- Terrain type as string (for easy GDScript use) ---
    String get_terrain_type(Vector2i pos) const;

    // --- Resource queries ---
    Dictionary get_resource_at(Vector2i pos) const;

    // --- Map metadata ---
    String get_filename() const;

    // --- Field queries: units on a tile ---
    int get_building_count_at(Vector2i pos) const;
    int get_vehicle_count_at(Vector2i pos) const;
};

} // namespace godot

#endif // MAXTREME_GAME_MAP_H
