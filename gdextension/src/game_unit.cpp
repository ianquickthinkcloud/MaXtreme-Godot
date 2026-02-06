#include "game_unit.h"

#include <godot_cpp/variant/utility_functions.hpp>

#include "game/data/units/unit.h"
#include "game/data/units/vehicle.h"
#include "game/data/units/building.h"
#include "game/data/units/unitdata.h"
#include "game/data/player/player.h"
#include "utility/position.h"

using namespace godot;

void GameUnit::_bind_methods() {
    // Identity
    ClassDB::bind_method(D_METHOD("get_id"), &GameUnit::get_id);
    ClassDB::bind_method(D_METHOD("get_name"), &GameUnit::get_name);
    ClassDB::bind_method(D_METHOD("get_type_name"), &GameUnit::get_type_name);
    ClassDB::bind_method(D_METHOD("is_vehicle"), &GameUnit::is_vehicle);
    ClassDB::bind_method(D_METHOD("is_building"), &GameUnit::is_building);

    // Position
    ClassDB::bind_method(D_METHOD("get_position"), &GameUnit::get_position);
    ClassDB::bind_method(D_METHOD("is_big"), &GameUnit::is_big);

    // Core stats
    ClassDB::bind_method(D_METHOD("get_hitpoints"), &GameUnit::get_hitpoints);
    ClassDB::bind_method(D_METHOD("get_hitpoints_max"), &GameUnit::get_hitpoints_max);
    ClassDB::bind_method(D_METHOD("get_armor"), &GameUnit::get_armor);
    ClassDB::bind_method(D_METHOD("get_damage"), &GameUnit::get_damage);
    ClassDB::bind_method(D_METHOD("get_speed"), &GameUnit::get_speed);
    ClassDB::bind_method(D_METHOD("get_speed_max"), &GameUnit::get_speed_max);
    ClassDB::bind_method(D_METHOD("get_scan"), &GameUnit::get_scan);
    ClassDB::bind_method(D_METHOD("get_range"), &GameUnit::get_range);
    ClassDB::bind_method(D_METHOD("get_shots"), &GameUnit::get_shots);
    ClassDB::bind_method(D_METHOD("get_shots_max"), &GameUnit::get_shots_max);
    ClassDB::bind_method(D_METHOD("get_ammo"), &GameUnit::get_ammo);
    ClassDB::bind_method(D_METHOD("get_ammo_max"), &GameUnit::get_ammo_max);

    // State
    ClassDB::bind_method(D_METHOD("is_disabled"), &GameUnit::is_disabled);
    ClassDB::bind_method(D_METHOD("get_disabled_turns"), &GameUnit::get_disabled_turns);
    ClassDB::bind_method(D_METHOD("is_sentry_active"), &GameUnit::is_sentry_active);
    ClassDB::bind_method(D_METHOD("is_manual_fire"), &GameUnit::is_manual_fire);
    ClassDB::bind_method(D_METHOD("is_attacking"), &GameUnit::is_attacking);
    ClassDB::bind_method(D_METHOD("is_being_attacked"), &GameUnit::is_being_attacked);
    ClassDB::bind_method(D_METHOD("get_stored_resources"), &GameUnit::get_stored_resources);
    ClassDB::bind_method(D_METHOD("get_stored_units_count"), &GameUnit::get_stored_units_count);

    // Owner
    ClassDB::bind_method(D_METHOD("get_owner_id"), &GameUnit::get_owner_id);

    // Full stats
    ClassDB::bind_method(D_METHOD("get_stats"), &GameUnit::get_stats);
}

GameUnit::GameUnit() {}
GameUnit::~GameUnit() {}

void GameUnit::set_internal_unit(cUnit* u) {
    unit = u;
}

// --- Identity ---

int GameUnit::get_id() const {
    if (!unit) return -1;
    return static_cast<int>(unit->getId());
}

String GameUnit::get_name() const {
    if (!unit) return String("");
    auto custom = unit->getCustomName();
    if (custom.has_value()) return String(custom.value().c_str());
    return get_type_name();
}

String GameUnit::get_type_name() const {
    if (!unit) return String("");
    return String(unit->getStaticUnitData().getDefaultName().c_str());
}

bool GameUnit::is_vehicle() const {
    if (!unit) return false;
    return unit->isAVehicle();
}

bool GameUnit::is_building() const {
    if (!unit) return false;
    return unit->isABuilding();
}

// --- Position ---

Vector2i GameUnit::get_position() const {
    if (!unit) return Vector2i(-1, -1);
    const auto& pos = unit->getPosition();
    return Vector2i(pos.x(), pos.y());
}

bool GameUnit::is_big() const {
    if (!unit) return false;
    return unit->getIsBig();
}

// --- Core stats ---

int GameUnit::get_hitpoints() const {
    if (!unit) return 0;
    return unit->data.getHitpoints();
}

int GameUnit::get_hitpoints_max() const {
    if (!unit) return 0;
    return unit->data.getHitpointsMax();
}

int GameUnit::get_armor() const {
    if (!unit) return 0;
    return unit->data.getArmor();
}

int GameUnit::get_damage() const {
    if (!unit) return 0;
    return unit->data.getDamage();
}

int GameUnit::get_speed() const {
    if (!unit) return 0;
    return unit->data.getSpeed();
}

int GameUnit::get_speed_max() const {
    if (!unit) return 0;
    return unit->data.getSpeedMax();
}

int GameUnit::get_scan() const {
    if (!unit) return 0;
    return unit->data.getScan();
}

int GameUnit::get_range() const {
    if (!unit) return 0;
    return unit->data.getRange();
}

int GameUnit::get_shots() const {
    if (!unit) return 0;
    return unit->data.getShots();
}

int GameUnit::get_shots_max() const {
    if (!unit) return 0;
    return unit->data.getShotsMax();
}

int GameUnit::get_ammo() const {
    if (!unit) return 0;
    return unit->data.getAmmo();
}

int GameUnit::get_ammo_max() const {
    if (!unit) return 0;
    return unit->data.getAmmoMax();
}

// --- State ---

bool GameUnit::is_disabled() const {
    if (!unit) return false;
    return unit->isDisabled();
}

int GameUnit::get_disabled_turns() const {
    if (!unit) return 0;
    return unit->getDisabledTurns();
}

bool GameUnit::is_sentry_active() const {
    if (!unit) return false;
    return unit->isSentryActive();
}

bool GameUnit::is_manual_fire() const {
    if (!unit) return false;
    return unit->isManualFireActive();
}

bool GameUnit::is_attacking() const {
    if (!unit) return false;
    return unit->isAttacking();
}

bool GameUnit::is_being_attacked() const {
    if (!unit) return false;
    return unit->isBeingAttacked();
}

int GameUnit::get_stored_resources() const {
    if (!unit) return 0;
    return unit->getStoredResources();
}

int GameUnit::get_stored_units_count() const {
    if (!unit) return 0;
    return static_cast<int>(unit->storedUnits.size());
}

// --- Owner ---

int GameUnit::get_owner_id() const {
    if (!unit || !unit->getOwner()) return -1;
    return unit->getOwner()->getId();
}

// --- Full stats dictionary ---

Dictionary GameUnit::get_stats() const {
    Dictionary stats;
    if (!unit) return stats;

    stats["id"] = get_id();
    stats["name"] = get_name();
    stats["type_name"] = get_type_name();
    stats["is_vehicle"] = is_vehicle();
    stats["is_building"] = is_building();
    stats["position"] = get_position();
    stats["is_big"] = is_big();

    stats["hitpoints"] = get_hitpoints();
    stats["hitpoints_max"] = get_hitpoints_max();
    stats["armor"] = get_armor();
    stats["damage"] = get_damage();
    stats["speed"] = get_speed();
    stats["speed_max"] = get_speed_max();
    stats["scan"] = get_scan();
    stats["range"] = get_range();
    stats["shots"] = get_shots();
    stats["shots_max"] = get_shots_max();
    stats["ammo"] = get_ammo();
    stats["ammo_max"] = get_ammo_max();

    stats["is_disabled"] = is_disabled();
    stats["is_sentry"] = is_sentry_active();
    stats["is_manual_fire"] = is_manual_fire();
    stats["stored_resources"] = get_stored_resources();
    stats["stored_units"] = get_stored_units_count();
    stats["owner_id"] = get_owner_id();

    return stats;
}
