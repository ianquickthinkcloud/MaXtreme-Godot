#include "game_unit.h"

#include <godot_cpp/variant/utility_functions.hpp>

#include "game/data/units/unit.h"
#include "game/data/units/vehicle.h"
#include "game/data/units/building.h"
#include "game/data/units/unitdata.h"
#include "game/data/units/commandodata.h"
#include "game/data/units/id.h"
#include "game/data/player/player.h"
#include "game/data/base/base.h"
#include "game/data/miningresource.h"
#include "utility/position.h"

using namespace godot;

// --- Internal cast helpers ---

cBuilding* GameUnit::as_building() const {
    if (!unit || !unit->isABuilding()) return nullptr;
    return dynamic_cast<cBuilding*>(unit);
}

cVehicle* GameUnit::as_vehicle() const {
    if (!unit || !unit->isAVehicle()) return nullptr;
    return dynamic_cast<cVehicle*>(unit);
}

void GameUnit::_bind_methods() {
    // Identity
    ClassDB::bind_method(D_METHOD("get_id"), &GameUnit::get_id);
    ClassDB::bind_method(D_METHOD("get_name"), &GameUnit::get_name);
    ClassDB::bind_method(D_METHOD("get_type_name"), &GameUnit::get_type_name);
    ClassDB::bind_method(D_METHOD("get_description"), &GameUnit::get_description);
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
    ClassDB::bind_method(D_METHOD("get_build_cost"), &GameUnit::get_build_cost);

    // Combat capability
    ClassDB::bind_method(D_METHOD("get_can_attack"), &GameUnit::get_can_attack);
    ClassDB::bind_method(D_METHOD("can_attack_air"), &GameUnit::can_attack_air);
    ClassDB::bind_method(D_METHOD("can_attack_ground"), &GameUnit::can_attack_ground);
    ClassDB::bind_method(D_METHOD("can_attack_sea"), &GameUnit::can_attack_sea);
    ClassDB::bind_method(D_METHOD("has_weapon"), &GameUnit::has_weapon);
    ClassDB::bind_method(D_METHOD("get_muzzle_type"), &GameUnit::get_muzzle_type);
    ClassDB::bind_method(D_METHOD("calc_damage_to", "target_armor"), &GameUnit::calc_damage_to);
    ClassDB::bind_method(D_METHOD("is_in_range_of", "target_pos"), &GameUnit::is_in_range_of);

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

    // Experience & version (Phase 20)
    ClassDB::bind_method(D_METHOD("get_commando_rank"), &GameUnit::get_commando_rank);
    ClassDB::bind_method(D_METHOD("get_commando_rank_name"), &GameUnit::get_commando_rank_name);
    ClassDB::bind_method(D_METHOD("is_dated"), &GameUnit::is_dated);
    ClassDB::bind_method(D_METHOD("get_version"), &GameUnit::get_version);

    // Capabilities & cargo
    ClassDB::bind_method(D_METHOD("get_capabilities"), &GameUnit::get_capabilities);
    ClassDB::bind_method(D_METHOD("get_stored_units"), &GameUnit::get_stored_units);

    // Construction capability (vehicles)
    ClassDB::bind_method(D_METHOD("get_can_build"), &GameUnit::get_can_build);
    ClassDB::bind_method(D_METHOD("is_constructor"), &GameUnit::is_constructor);
    ClassDB::bind_method(D_METHOD("get_buildable_types"), &GameUnit::get_buildable_types);
    ClassDB::bind_method(D_METHOD("is_building_a_building"), &GameUnit::is_building_a_building);
    ClassDB::bind_method(D_METHOD("get_build_turns_remaining"), &GameUnit::get_build_turns_remaining);
    ClassDB::bind_method(D_METHOD("get_build_costs_remaining"), &GameUnit::get_build_costs_remaining);
    ClassDB::bind_method(D_METHOD("get_build_costs_start"), &GameUnit::get_build_costs_start);

    // Building production state
    ClassDB::bind_method(D_METHOD("is_working"), &GameUnit::is_working);
    ClassDB::bind_method(D_METHOD("can_start_work"), &GameUnit::can_start_work);
    ClassDB::bind_method(D_METHOD("get_build_list_size"), &GameUnit::get_build_list_size);
    ClassDB::bind_method(D_METHOD("get_build_list"), &GameUnit::get_build_list);
    ClassDB::bind_method(D_METHOD("get_producible_types"), &GameUnit::get_producible_types);
    ClassDB::bind_method(D_METHOD("get_build_speed"), &GameUnit::get_build_speed);
    ClassDB::bind_method(D_METHOD("get_metal_per_round"), &GameUnit::get_metal_per_round);
    ClassDB::bind_method(D_METHOD("get_repeat_build"), &GameUnit::get_repeat_build);

    // Building mining state
    ClassDB::bind_method(D_METHOD("get_mining_production"), &GameUnit::get_mining_production);
    ClassDB::bind_method(D_METHOD("get_mining_max"), &GameUnit::get_mining_max);

    // Building research state
    ClassDB::bind_method(D_METHOD("get_research_area"), &GameUnit::get_research_area);

    // Building upgrade & misc
    ClassDB::bind_method(D_METHOD("can_be_upgraded"), &GameUnit::can_be_upgraded);
    ClassDB::bind_method(D_METHOD("connects_to_base"), &GameUnit::connects_to_base);
    ClassDB::bind_method(D_METHOD("get_energy_production"), &GameUnit::get_energy_production);
    ClassDB::bind_method(D_METHOD("get_energy_need"), &GameUnit::get_energy_need);

    // Phase 26: Construction enhancements
    ClassDB::bind_method(D_METHOD("get_turbo_build_info", "building_type_id"), &GameUnit::get_turbo_build_info);
    ClassDB::bind_method(D_METHOD("can_build_path"), &GameUnit::can_build_path);
    ClassDB::bind_method(D_METHOD("get_connection_flags"), &GameUnit::get_connection_flags);
    ClassDB::bind_method(D_METHOD("get_max_build_factor"), &GameUnit::get_max_build_factor);
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

String GameUnit::get_description() const {
    if (!unit) return String("");
    return String(unit->getStaticUnitData().getDefaultDescription().c_str());
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

int GameUnit::get_build_cost() const {
    if (!unit) return 0;
    return unit->data.getBuildCost();
}

// --- Combat capability ---

int GameUnit::get_can_attack() const {
    if (!unit) return 0;
    return static_cast<int>(unit->getStaticUnitData().canAttack);
}

bool GameUnit::can_attack_air() const {
    if (!unit) return false;
    return (unit->getStaticUnitData().canAttack & 1) != 0; // eTerrainFlag::Air = 1
}

bool GameUnit::can_attack_ground() const {
    if (!unit) return false;
    return (unit->getStaticUnitData().canAttack & 4) != 0; // eTerrainFlag::Ground = 4
}

bool GameUnit::can_attack_sea() const {
    if (!unit) return false;
    return (unit->getStaticUnitData().canAttack & 2) != 0; // eTerrainFlag::Sea = 2
}

bool GameUnit::has_weapon() const {
    if (!unit) return false;
    return unit->getStaticUnitData().canAttack != 0;
}

String GameUnit::get_muzzle_type() const {
    if (!unit) return String("None");
    switch (unit->getStaticUnitData().muzzleType) {
        case eMuzzleType::Big: return String("Big");
        case eMuzzleType::Rocket: return String("Rocket");
        case eMuzzleType::Small: return String("Small");
        case eMuzzleType::Med: return String("Med");
        case eMuzzleType::MedLong: return String("MedLong");
        case eMuzzleType::RocketCluster: return String("RocketCluster");
        case eMuzzleType::Torpedo: return String("Torpedo");
        case eMuzzleType::Sniper: return String("Sniper");
        default: return String("None");
    }
}

int GameUnit::calc_damage_to(int target_armor) const {
    if (!unit) return 0;
    int dmg = unit->data.getDamage() - target_armor;
    return std::max(1, dmg); // Minimum damage is always 1
}

bool GameUnit::is_in_range_of(Vector2i target_pos) const {
    if (!unit) return false;
    int range = unit->data.getRange();
    if (range <= 0) return false;
    const auto& pos = unit->getPosition();
    int dx = target_pos.x - pos.x();
    int dy = target_pos.y - pos.y();
    return (dx * dx + dy * dy) <= (range * range);
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
    stats["description"] = get_description();
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
    stats["build_cost"] = get_build_cost();

    stats["can_attack"] = get_can_attack();
    stats["has_weapon"] = has_weapon();
    stats["can_attack_air"] = can_attack_air();
    stats["can_attack_ground"] = can_attack_ground();
    stats["can_attack_sea"] = can_attack_sea();
    stats["muzzle_type"] = get_muzzle_type();

    stats["is_disabled"] = is_disabled();
    stats["is_sentry"] = is_sentry_active();
    stats["is_manual_fire"] = is_manual_fire();
    stats["is_attacking"] = is_attacking();
    stats["is_being_attacked"] = is_being_attacked();
    stats["stored_resources"] = get_stored_resources();
    stats["stored_units"] = get_stored_units_count();
    stats["owner_id"] = get_owner_id();

    // Building/economy extras
    stats["can_build"] = get_can_build();
    stats["is_constructor"] = is_constructor();
    stats["is_working"] = is_working();

    return stats;
}

// ========== CONSTRUCTION CAPABILITY (vehicles) ==========

String GameUnit::get_can_build() const {
    if (!unit) return String("");
    return String(unit->getStaticUnitData().canBuild.c_str());
}

bool GameUnit::is_constructor() const {
    if (!unit) return false;
    return !unit->getStaticUnitData().canBuild.empty();
}

Array GameUnit::get_buildable_types() const {
    Array result;
    if (!unit) return result;

    const auto& canBuild = unit->getStaticUnitData().canBuild;
    if (canBuild.empty()) return result;

    // Iterate all static unit data to find buildings whose buildAs matches this constructor's canBuild
    const auto& allStatic = UnitsDataGlobal.getStaticUnitsData();
    for (const auto& sud : allStatic) {
        if (!sud.ID.isABuilding()) continue;
        if (sud.buildAs.empty()) continue;

        // Check if canBuild contains buildAs (e.g. canBuild="big,small", buildAs="small")
        if (canBuild.find(sud.buildAs) != std::string::npos) {
            Dictionary entry;
            entry["id"] = String(sud.ID.getText().c_str());
            entry["name"] = String(sud.getDefaultName().c_str());
            // Get dynamic data for build cost
            const auto& dyn = UnitsDataGlobal.getDynamicUnitData(sud.ID, -1);
            entry["cost"] = dyn.getBuildCost();
            entry["is_big"] = sud.buildingData.isBig;
            result.push_back(entry);
        }
    }
    return result;
}

bool GameUnit::is_building_a_building() const {
    auto* v = as_vehicle();
    if (!v) return false;
    return v->isUnitBuildingABuilding();
}

int GameUnit::get_build_turns_remaining() const {
    auto* v = as_vehicle();
    if (!v) return 0;
    return v->getBuildTurns();
}

int GameUnit::get_build_costs_remaining() const {
    auto* v = as_vehicle();
    if (!v) return 0;
    return v->getBuildCosts();
}

int GameUnit::get_build_costs_start() const {
    auto* v = as_vehicle();
    if (!v) return 0;
    return v->getBuildCostsStart();
}

// ========== BUILDING PRODUCTION STATE ==========

bool GameUnit::is_working() const {
    auto* b = as_building();
    if (b) return b->isUnitWorking();
    // For vehicles, check if building a building
    auto* v = as_vehicle();
    if (v) return v->isUnitBuildingABuilding();
    return false;
}

bool GameUnit::can_start_work() const {
    auto* b = as_building();
    if (!b) return false;
    return b->buildingCanBeStarted();
}

int GameUnit::get_build_list_size() const {
    auto* b = as_building();
    if (!b) return 0;
    return static_cast<int>(b->getBuildListSize());
}

Array GameUnit::get_build_list() const {
    Array result;
    auto* b = as_building();
    if (!b) return result;

    size_t count = b->getBuildListSize();
    for (size_t i = 0; i < count; ++i) {
        const auto& item = b->getBuildListItem(i);
        Dictionary entry;
        entry["type_id"] = String(item.getType().getText().c_str());
        // Look up name from global data
        if (UnitsDataGlobal.isValidId(item.getType())) {
            const auto& sud = UnitsDataGlobal.getStaticUnitData(item.getType());
            entry["type_name"] = String(sud.getDefaultName().c_str());
            const auto& dyn = UnitsDataGlobal.getDynamicUnitData(item.getType(), -1);
            entry["total_cost"] = dyn.getBuildCost();
        } else {
            entry["type_name"] = String("Unknown");
            entry["total_cost"] = 0;
        }
        entry["remaining_metal"] = item.getRemainingMetal();
        result.push_back(entry);
    }
    return result;
}

Array GameUnit::get_producible_types() const {
    Array result;
    auto* b = as_building();
    if (!b) return result;

    // A factory's canBuild string determines what vehicle types it can produce
    const auto& canBuild = unit->getStaticUnitData().canBuild;
    if (canBuild.empty()) return result;

    const auto& allStatic = UnitsDataGlobal.getStaticUnitsData();
    for (const auto& sud : allStatic) {
        if (!sud.ID.isAVehicle()) continue;
        if (sud.buildAs.empty()) continue;

        if (canBuild.find(sud.buildAs) != std::string::npos) {
            Dictionary entry;
            entry["id"] = String(sud.ID.getText().c_str());
            entry["name"] = String(sud.getDefaultName().c_str());
            const auto& dyn = UnitsDataGlobal.getDynamicUnitData(sud.ID, -1);
            entry["cost"] = dyn.getBuildCost();
            result.push_back(entry);
        }
    }
    return result;
}

int GameUnit::get_build_speed() const {
    auto* b = as_building();
    if (!b) return 0;
    return b->getBuildSpeed();
}

int GameUnit::get_metal_per_round() const {
    auto* b = as_building();
    if (!b) return 0;
    return b->getMetalPerRound();
}

bool GameUnit::get_repeat_build() const {
    auto* b = as_building();
    if (!b) return false;
    return b->getRepeatBuild();
}

// ========== BUILDING MINING STATE ==========

Dictionary GameUnit::get_mining_production() const {
    Dictionary result;
    result["metal"] = 0;
    result["oil"] = 0;
    result["gold"] = 0;

    auto* b = as_building();
    if (!b) return result;

    // prod is public member on cBuilding
    result["metal"] = b->prod.metal;
    result["oil"] = b->prod.oil;
    result["gold"] = b->prod.gold;
    return result;
}

Dictionary GameUnit::get_mining_max() const {
    Dictionary result;
    result["metal"] = 0;
    result["oil"] = 0;
    result["gold"] = 0;

    auto* b = as_building();
    if (!b) return result;

    const auto& maxProd = b->getMaxProd();
    result["metal"] = maxProd.metal;
    result["oil"] = maxProd.oil;
    result["gold"] = maxProd.gold;
    return result;
}

// ========== BUILDING RESEARCH STATE ==========

int GameUnit::get_research_area() const {
    auto* b = as_building();
    if (!b) return -1;
    if (!unit->getStaticUnitData().buildingData.canResearch) return -1;
    return static_cast<int>(b->getResearchArea());
}

// ========== BUILDING UPGRADE & MISC ==========

bool GameUnit::can_be_upgraded() const {
    auto* b = as_building();
    if (!b) return false;
    return b->buildingCanBeUpgraded();
}

bool GameUnit::connects_to_base() const {
    if (!unit) return false;
    return unit->getStaticUnitData().buildingData.connectsToBase;
}

int GameUnit::get_energy_production() const {
    if (!unit) return 0;
    return unit->getStaticUnitData().produceEnergy;
}

int GameUnit::get_energy_need() const {
    if (!unit) return 0;
    return unit->getStaticUnitData().needsEnergy;
}

// ========== EXPERIENCE & VERSION (Phase 20) ==========

int GameUnit::get_commando_rank() const {
    auto* v = as_vehicle();
    if (!v) return -1;
    // Only commandos (units with canCapture or canDisable) have ranks
    if (!v->getStaticUnitData().vehicleData.canCapture &&
        !v->getStaticUnitData().vehicleData.canDisable) return -1;
    return cCommandoData::getLevel(v->getCommandoData().getSuccessCount());
}

String GameUnit::get_commando_rank_name() const {
    int rank = get_commando_rank();
    if (rank < 0) return String("");
    // Rank names from the original game
    static const char* rank_names[] = {
        "Greenhorn", "Average", "Veteran", "Expert", "Elite", "Grand Master"
    };
    int idx = std::min(rank, 5);
    return String(rank_names[idx]);
}

bool GameUnit::is_dated() const {
    if (!unit || !unit->getOwner()) return false;
    const auto* latestData = unit->getOwner()->getLastUnitData(unit->data.getId());
    if (!latestData) return false;
    return unit->data.getVersion() < latestData->getVersion();
}

int GameUnit::get_version() const {
    if (!unit) return 0;
    return unit->data.getVersion();
}

// ========== CAPABILITY FLAGS ==========

Dictionary GameUnit::get_capabilities() const {
    Dictionary caps;
    if (!unit) return caps;

    const auto& sd = unit->getStaticUnitData();

    // Common capabilities
    caps["has_weapon"] = (sd.canAttack != 0);
    caps["can_store_units"] = (sd.storageUnitsMax > 0);
    caps["can_store_resources"] = (sd.storageResMax > 0);
    caps["storage_units_max"] = static_cast<int>(sd.storageUnitsMax);
    caps["storage_res_max"] = sd.storageResMax;
    caps["is_stealth"] = (sd.isStealthOn != 0);
    caps["can_repair"] = sd.canRearm;   // Note: canRearm covers repair trucks
    caps["can_rearm"] = sd.canRepair;    // Note: canRepair covers ammo trucks

    // Vehicle-specific
    caps["can_survey"] = sd.vehicleData.canSurvey;
    caps["can_place_mines"] = sd.vehicleData.canPlaceMines;
    caps["can_clear_area"] = sd.vehicleData.canClearArea;
    caps["can_capture"] = sd.vehicleData.canCapture;
    caps["can_disable"] = sd.vehicleData.canDisable;

    // Building-specific
    caps["can_self_destroy"] = sd.buildingData.canSelfDestroy;

    return caps;
}

// ========== STORED UNITS (CARGO) ==========

Array GameUnit::get_stored_units() const {
    Array result;
    if (!unit) return result;

    for (const auto* stored : unit->storedUnits) {
        if (!stored) continue;
        Dictionary entry;
        entry["id"] = static_cast<int>(stored->getId());
        entry["name"] = String(stored->getStaticUnitData().getDefaultName().c_str());
        entry["type_name"] = String(stored->getStaticUnitData().getDefaultName().c_str());
        entry["hp"] = stored->data.getHitpoints();
        entry["hp_max"] = stored->data.getHitpointsMax();
        entry["ammo"] = stored->data.getAmmo();
        entry["ammo_max"] = stored->data.getAmmoMax();
        result.push_back(entry);
    }
    return result;
}

// ========== PHASE 26: CONSTRUCTION ENHANCEMENTS ==========

Dictionary GameUnit::get_turbo_build_info(String building_type_id) const {
    Dictionary result;
    result["turns_0"] = 0; result["cost_0"] = 0;
    result["turns_1"] = 0; result["cost_1"] = 0;
    result["turns_2"] = 0; result["cost_2"] = 0;

    auto* v = as_vehicle();
    if (!v) return result;

    // Parse building type ID
    std::string idStr = building_type_id.utf8().get_data();
    sID buildingID;
    auto dotPos = idStr.find('.');
    if (dotPos != std::string::npos) {
        buildingID.firstPart = std::stoi(idStr.substr(0, dotPos));
        buildingID.secondPart = std::stoi(idStr.substr(dotPos + 1));
    }

    // Get the build cost from the player's latest unit data
    int buildCost = 0;
    if (v->getOwner()) {
        const auto* lastData = v->getOwner()->getLastUnitData(buildingID);
        if (lastData) buildCost = lastData->getBuildCost();
    }
    if (buildCost <= 0) {
        // Fallback to global data
        const auto& dyn = UnitsDataGlobal.getDynamicUnitData(buildingID, -1);
        buildCost = dyn.getBuildCost();
    }

    std::array<int, 3> turboBuildTurns;
    std::array<int, 3> turboBuildCosts;
    v->calcTurboBuild(turboBuildTurns, turboBuildCosts, buildCost);

    result["turns_0"] = turboBuildTurns[0];
    result["cost_0"] = turboBuildCosts[0];
    result["turns_1"] = turboBuildTurns[1];
    result["cost_1"] = turboBuildCosts[1];
    result["turns_2"] = turboBuildTurns[2];
    result["cost_2"] = turboBuildCosts[2];

    return result;
}

bool GameUnit::can_build_path() const {
    auto* v = as_vehicle();
    if (!v) return false;
    return v->getStaticUnitData().vehicleData.canBuildPath;
}

Dictionary GameUnit::get_connection_flags() const {
    Dictionary result;
    result["connects_to_base"] = false;
    result["BaseN"] = false;
    result["BaseE"] = false;
    result["BaseS"] = false;
    result["BaseW"] = false;
    result["BaseBN"] = false;
    result["BaseBE"] = false;
    result["BaseBS"] = false;
    result["BaseBW"] = false;

    auto* b = as_building();
    if (!b) return result;

    result["connects_to_base"] = b->getStaticData().connectsToBase;
    result["BaseN"] = b->BaseN;
    result["BaseE"] = b->BaseE;
    result["BaseS"] = b->BaseS;
    result["BaseW"] = b->BaseW;
    result["BaseBN"] = b->BaseBN;
    result["BaseBE"] = b->BaseBE;
    result["BaseBS"] = b->BaseBS;
    result["BaseBW"] = b->BaseBW;

    return result;
}

int GameUnit::get_max_build_factor() const {
    if (!unit) return 0;
    return unit->getStaticUnitData().buildingData.maxBuildFactor;
}
