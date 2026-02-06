#include "game_map.h"

#include <godot_cpp/variant/utility_functions.hpp>

#include "game/data/map/map.h"
#include "utility/position.h"

using namespace godot;

void GameMap::_bind_methods() {
    ClassDB::bind_method(D_METHOD("get_size"), &GameMap::get_size);
    ClassDB::bind_method(D_METHOD("get_width"), &GameMap::get_width);
    ClassDB::bind_method(D_METHOD("get_height"), &GameMap::get_height);
    ClassDB::bind_method(D_METHOD("is_valid_position", "pos"), &GameMap::is_valid_position);

    ClassDB::bind_method(D_METHOD("is_water", "pos"), &GameMap::is_water);
    ClassDB::bind_method(D_METHOD("is_coast", "pos"), &GameMap::is_coast);
    ClassDB::bind_method(D_METHOD("is_blocked", "pos"), &GameMap::is_blocked);
    ClassDB::bind_method(D_METHOD("is_ground", "pos"), &GameMap::is_ground);
    ClassDB::bind_method(D_METHOD("get_terrain_type", "pos"), &GameMap::get_terrain_type);

    ClassDB::bind_method(D_METHOD("get_resource_at", "pos"), &GameMap::get_resource_at);
    ClassDB::bind_method(D_METHOD("get_filename"), &GameMap::get_filename);

    ClassDB::bind_method(D_METHOD("get_building_count_at", "pos"), &GameMap::get_building_count_at);
    ClassDB::bind_method(D_METHOD("get_vehicle_count_at", "pos"), &GameMap::get_vehicle_count_at);
}

GameMap::GameMap() {}
GameMap::~GameMap() {}

void GameMap::set_internal_map(std::shared_ptr<cMap> m) {
    map = m;
}

// --- Map geometry ---

Vector2i GameMap::get_size() const {
    if (!map) return Vector2i(0, 0);
    auto s = map->getSize();
    return Vector2i(s.x(), s.y());
}

int GameMap::get_width() const {
    if (!map) return 0;
    return map->getSize().x();
}

int GameMap::get_height() const {
    if (!map) return 0;
    return map->getSize().y();
}

bool GameMap::is_valid_position(Vector2i pos) const {
    if (!map) return false;
    return map->isValidPosition(cPosition(pos.x, pos.y));
}

// --- Terrain queries ---

bool GameMap::is_water(Vector2i pos) const {
    if (!map) return false;
    return map->isWater(cPosition(pos.x, pos.y));
}

bool GameMap::is_coast(Vector2i pos) const {
    if (!map) return false;
    return map->isCoast(cPosition(pos.x, pos.y));
}

bool GameMap::is_blocked(Vector2i pos) const {
    if (!map) return false;
    return map->isBlocked(cPosition(pos.x, pos.y));
}

bool GameMap::is_ground(Vector2i pos) const {
    if (!map) return false;
    cPosition p(pos.x, pos.y);
    return !map->isWater(p) && !map->isCoast(p) && !map->isBlocked(p);
}

String GameMap::get_terrain_type(Vector2i pos) const {
    if (!map) return String("invalid");
    cPosition p(pos.x, pos.y);
    if (!map->isValidPosition(p)) return String("invalid");
    if (map->isBlocked(p)) return String("blocked");
    if (map->isWater(p)) return String("water");
    if (map->isCoast(p)) return String("coast");
    return String("ground");
}

// --- Resource queries ---

Dictionary GameMap::get_resource_at(Vector2i pos) const {
    Dictionary result;
    if (!map) return result;

    cPosition p(pos.x, pos.y);
    if (!map->isValidPosition(p)) return result;

    const auto& res = map->getResource(p);
    result["value"] = static_cast<int>(res.value);

    switch (res.typ) {
        case eResourceType::None:  result["type"] = "none"; break;
        case eResourceType::Metal: result["type"] = "metal"; break;
        case eResourceType::Oil:   result["type"] = "oil"; break;
        case eResourceType::Gold:  result["type"] = "gold"; break;
        default: result["type"] = "unknown"; break;
    }

    return result;
}

// --- Map metadata ---

String GameMap::get_filename() const {
    if (!map) return String("");
    auto fn = map->getFilename().string();
    return String(fn.c_str());
}

// --- Field queries ---

int GameMap::get_building_count_at(Vector2i pos) const {
    if (!map) return 0;
    cPosition p(pos.x, pos.y);
    if (!map->isValidPosition(p)) return 0;
    return static_cast<int>(map->getField(p).getBuildings().size());
}

int GameMap::get_vehicle_count_at(Vector2i pos) const {
    if (!map) return 0;
    cPosition p(pos.x, pos.y);
    if (!map->isValidPosition(p)) return 0;
    return static_cast<int>(map->getField(p).getVehicles().size());
}
