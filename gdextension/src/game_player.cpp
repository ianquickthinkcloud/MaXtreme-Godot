#include "game_player.h"

#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/dictionary.hpp>

#include "game/data/player/player.h"
#include "game/data/base/base.h"
#include "game/data/miningresource.h"
#include "game/data/rangemap.h"
#include "game/logic/upgradecalculator.h"

using namespace godot;

void GamePlayer::_bind_methods() {
    // Identity
    ClassDB::bind_method(D_METHOD("get_name"), &GamePlayer::get_name);
    ClassDB::bind_method(D_METHOD("get_id"), &GamePlayer::get_id);
    ClassDB::bind_method(D_METHOD("get_color"), &GamePlayer::get_color);
    ClassDB::bind_method(D_METHOD("get_clan"), &GamePlayer::get_clan);

    // Economy
    ClassDB::bind_method(D_METHOD("get_credits"), &GamePlayer::get_credits);
    ClassDB::bind_method(D_METHOD("get_score"), &GamePlayer::get_score);

    // Unit counts
    ClassDB::bind_method(D_METHOD("get_vehicle_count"), &GamePlayer::get_vehicle_count);
    ClassDB::bind_method(D_METHOD("get_building_count"), &GamePlayer::get_building_count);

    // Research
    ClassDB::bind_method(D_METHOD("get_research_centers_working"), &GamePlayer::get_research_centers_working);

    // Game state
    ClassDB::bind_method(D_METHOD("is_defeated"), &GamePlayer::is_defeated);
    ClassDB::bind_method(D_METHOD("has_finished_turn"), &GamePlayer::has_finished_turn);

    // Statistics
    ClassDB::bind_method(D_METHOD("get_built_vehicles_count"), &GamePlayer::get_built_vehicles_count);
    ClassDB::bind_method(D_METHOD("get_lost_vehicles_count"), &GamePlayer::get_lost_vehicles_count);
    ClassDB::bind_method(D_METHOD("get_built_buildings_count"), &GamePlayer::get_built_buildings_count);
    ClassDB::bind_method(D_METHOD("get_lost_buildings_count"), &GamePlayer::get_lost_buildings_count);

    // Base resource storage (Phase 8)
    ClassDB::bind_method(D_METHOD("get_resource_storage"), &GamePlayer::get_resource_storage);
    ClassDB::bind_method(D_METHOD("get_resource_production"), &GamePlayer::get_resource_production);
    ClassDB::bind_method(D_METHOD("get_resource_needed"), &GamePlayer::get_resource_needed);

    // Energy balance
    ClassDB::bind_method(D_METHOD("get_energy_balance"), &GamePlayer::get_energy_balance);

    // Human balance
    ClassDB::bind_method(D_METHOD("get_human_balance"), &GamePlayer::get_human_balance);

    // Research state
    ClassDB::bind_method(D_METHOD("get_research_levels"), &GamePlayer::get_research_levels);
    ClassDB::bind_method(D_METHOD("get_research_centers_per_area"), &GamePlayer::get_research_centers_per_area);
    ClassDB::bind_method(D_METHOD("get_research_remaining_turns"), &GamePlayer::get_research_remaining_turns);

    // Economy summary
    ClassDB::bind_method(D_METHOD("get_economy_summary"), &GamePlayer::get_economy_summary);

    // Resource survey & sub-bases (Phase 22)
    ClassDB::bind_method(D_METHOD("has_resource_explored", "pos"), &GamePlayer::has_resource_explored);
    ClassDB::bind_method(D_METHOD("get_sub_bases"), &GamePlayer::get_sub_bases);

    // Fog of War / Visibility (Phase 14)
    ClassDB::bind_method(D_METHOD("can_see_at", "pos"), &GamePlayer::can_see_at);
    ClassDB::bind_method(D_METHOD("get_scan_map_data"), &GamePlayer::get_scan_map_data);
    ClassDB::bind_method(D_METHOD("get_scan_map_size"), &GamePlayer::get_scan_map_size);
}

GamePlayer::GamePlayer() {}
GamePlayer::~GamePlayer() {}

void GamePlayer::set_internal_player(std::shared_ptr<cPlayer> p) {
    player = p;
}

// --- Identity ---

String GamePlayer::get_name() const {
    if (!player) return String("");
    return String(player->getName().c_str());
}

int GamePlayer::get_id() const {
    if (!player) return -1;
    return player->getId();
}

Color GamePlayer::get_color() const {
    if (!player) return Color(1, 1, 1);
    const auto& c = player->getColor();
    return Color(c.r / 255.0f, c.g / 255.0f, c.b / 255.0f);
}

int GamePlayer::get_clan() const {
    if (!player) return -1;
    return player->getClan();
}

// --- Economy ---

int GamePlayer::get_credits() const {
    if (!player) return 0;
    return player->getCredits();
}

int GamePlayer::get_score() const {
    if (!player) return 0;
    return player->getScore();
}

// --- Unit counts ---

int GamePlayer::get_vehicle_count() const {
    if (!player) return 0;
    return static_cast<int>(player->getVehicles().size());
}

int GamePlayer::get_building_count() const {
    if (!player) return 0;
    return static_cast<int>(player->getBuildings().size());
}

// --- Research ---

int GamePlayer::get_research_centers_working() const {
    if (!player) return 0;
    return player->getResearchCentersWorkingTotal();
}

// --- Game state ---

bool GamePlayer::is_defeated() const {
    if (!player) return false;
    return player->isDefeated;
}

bool GamePlayer::has_finished_turn() const {
    if (!player) return false;
    return player->getHasFinishedTurn();
}

// --- Statistics ---

int GamePlayer::get_built_vehicles_count() const {
    if (!player) return 0;
    return static_cast<int>(player->getGameOverStat().builtVehiclesCount);
}

int GamePlayer::get_lost_vehicles_count() const {
    if (!player) return 0;
    return static_cast<int>(player->getGameOverStat().lostVehiclesCount);
}

int GamePlayer::get_built_buildings_count() const {
    if (!player) return 0;
    return static_cast<int>(player->getGameOverStat().builtBuildingsCount);
}

int GamePlayer::get_lost_buildings_count() const {
    if (!player) return 0;
    return static_cast<int>(player->getGameOverStat().lostBuildingsCount);
}

// ========== BASE RESOURCE STORAGE (Phase 8) ==========

Dictionary GamePlayer::get_resource_storage() const {
    Dictionary result;
    result["metal"] = 0;
    result["oil"] = 0;
    result["gold"] = 0;
    result["metal_max"] = 0;
    result["oil_max"] = 0;
    result["gold_max"] = 0;
    if (!player) return result;

    int metal = 0, oil = 0, gold = 0;
    int metalMax = 0, oilMax = 0, goldMax = 0;

    for (const auto& sb : player->base.SubBases) {
        const auto& stored = sb->getResourcesStored();
        const auto& maxStored = sb->getMaxResourcesStored();
        metal += stored.metal;
        oil += stored.oil;
        gold += stored.gold;
        metalMax += maxStored.metal;
        oilMax += maxStored.oil;
        goldMax += maxStored.gold;
    }

    result["metal"] = metal;
    result["oil"] = oil;
    result["gold"] = gold;
    result["metal_max"] = metalMax;
    result["oil_max"] = oilMax;
    result["gold_max"] = goldMax;
    return result;
}

Dictionary GamePlayer::get_resource_production() const {
    Dictionary result;
    result["metal"] = 0;
    result["oil"] = 0;
    result["gold"] = 0;
    if (!player) return result;

    int metal = 0, oil = 0, gold = 0;

    for (const auto& sb : player->base.SubBases) {
        const auto& prod = sb->getProd();
        metal += prod.metal;
        oil += prod.oil;
        gold += prod.gold;
    }

    result["metal"] = metal;
    result["oil"] = oil;
    result["gold"] = gold;
    return result;
}

Dictionary GamePlayer::get_resource_needed() const {
    Dictionary result;
    result["metal"] = 0;
    result["oil"] = 0;
    result["gold"] = 0;
    if (!player) return result;

    int metal = 0, oil = 0, gold = 0;

    for (const auto& sb : player->base.SubBases) {
        const auto& needed = sb->getResourcesNeeded();
        metal += needed.metal;
        oil += needed.oil;
        gold += needed.gold;
    }

    result["metal"] = metal;
    result["oil"] = oil;
    result["gold"] = gold;
    return result;
}

// ========== ENERGY BALANCE ==========

Dictionary GamePlayer::get_energy_balance() const {
    Dictionary result;
    result["production"] = 0;
    result["need"] = 0;
    result["max_production"] = 0;
    result["max_need"] = 0;
    if (!player) return result;

    int prod = 0, need = 0, maxProd = 0, maxNeed = 0;

    for (const auto& sb : player->base.SubBases) {
        prod += sb->getEnergyProd();
        need += sb->getEnergyNeed();
        maxProd += sb->getMaxEnergyProd();
        maxNeed += sb->getMaxEnergyNeed();
    }

    result["production"] = prod;
    result["need"] = need;
    result["max_production"] = maxProd;
    result["max_need"] = maxNeed;
    return result;
}

// ========== HUMAN BALANCE ==========

Dictionary GamePlayer::get_human_balance() const {
    Dictionary result;
    result["production"] = 0;
    result["need"] = 0;
    result["max_need"] = 0;
    if (!player) return result;

    int prod = 0, need = 0, maxNeed = 0;

    for (const auto& sb : player->base.SubBases) {
        prod += sb->getHumanProd();
        need += sb->getHumanNeed();
        maxNeed += sb->getMaxHumanNeed();
    }

    result["production"] = prod;
    result["need"] = need;
    result["max_need"] = maxNeed;
    return result;
}

// ========== RESEARCH STATE ==========

Dictionary GamePlayer::get_research_levels() const {
    Dictionary result;
    result["attack"] = 0;
    result["shots"] = 0;
    result["range"] = 0;
    result["armor"] = 0;
    result["hitpoints"] = 0;
    result["speed"] = 0;
    result["scan"] = 0;
    result["cost"] = 0;
    if (!player) return result;

    const auto& research = player->getResearchState();
    result["attack"] = research.getCurResearchLevel(cResearch::eResearchArea::AttackResearch);
    result["shots"] = research.getCurResearchLevel(cResearch::eResearchArea::ShotsResearch);
    result["range"] = research.getCurResearchLevel(cResearch::eResearchArea::RangeResearch);
    result["armor"] = research.getCurResearchLevel(cResearch::eResearchArea::ArmorResearch);
    result["hitpoints"] = research.getCurResearchLevel(cResearch::eResearchArea::HitpointsResearch);
    result["speed"] = research.getCurResearchLevel(cResearch::eResearchArea::SpeedResearch);
    result["scan"] = research.getCurResearchLevel(cResearch::eResearchArea::ScanResearch);
    result["cost"] = research.getCurResearchLevel(cResearch::eResearchArea::CostResearch);
    return result;
}

Array GamePlayer::get_research_centers_per_area() const {
    Array result;
    for (int i = 0; i < 8; ++i) result.push_back(0);
    if (!player) return result;

    result[0] = player->getResearchCentersWorkingOnArea(cResearch::eResearchArea::AttackResearch);
    result[1] = player->getResearchCentersWorkingOnArea(cResearch::eResearchArea::ShotsResearch);
    result[2] = player->getResearchCentersWorkingOnArea(cResearch::eResearchArea::RangeResearch);
    result[3] = player->getResearchCentersWorkingOnArea(cResearch::eResearchArea::ArmorResearch);
    result[4] = player->getResearchCentersWorkingOnArea(cResearch::eResearchArea::HitpointsResearch);
    result[5] = player->getResearchCentersWorkingOnArea(cResearch::eResearchArea::SpeedResearch);
    result[6] = player->getResearchCentersWorkingOnArea(cResearch::eResearchArea::ScanResearch);
    result[7] = player->getResearchCentersWorkingOnArea(cResearch::eResearchArea::CostResearch);
    return result;
}

// ========== RESEARCH PROGRESS (Phase 21) ==========

Array GamePlayer::get_research_remaining_turns() const {
    Array result;
    for (int i = 0; i < 8; ++i) result.push_back(0);
    if (!player) return result;

    const auto& research = player->getResearchState();
    const auto areas = {
        cResearch::eResearchArea::AttackResearch,
        cResearch::eResearchArea::ShotsResearch,
        cResearch::eResearchArea::RangeResearch,
        cResearch::eResearchArea::ArmorResearch,
        cResearch::eResearchArea::HitpointsResearch,
        cResearch::eResearchArea::SpeedResearch,
        cResearch::eResearchArea::ScanResearch,
        cResearch::eResearchArea::CostResearch,
    };
    int idx = 0;
    for (auto area : areas) {
        int centers = player->getResearchCentersWorkingOnArea(area);
        result[idx] = research.getRemainingTurns(area, centers);
        idx++;
    }
    return result;
}

// ========== ECONOMY SUMMARY ==========

Dictionary GamePlayer::get_economy_summary() const {
    Dictionary result;
    result["credits"] = get_credits();
    result["resources"] = get_resource_storage();
    result["production"] = get_resource_production();
    result["needed"] = get_resource_needed();
    result["energy"] = get_energy_balance();
    result["humans"] = get_human_balance();
    result["research"] = get_research_levels();
    return result;
}

// ========== RESOURCE SURVEY & SUB-BASES (Phase 22) ==========

bool GamePlayer::has_resource_explored(Vector2i pos) const {
    if (!player) return false;
    return player->hasResourceExplored(cPosition(pos.x, pos.y));
}

Array GamePlayer::get_sub_bases() const {
    Array result;
    if (!player) return result;

    for (const auto& sb : player->base.SubBases) {
        Dictionary info;
        const auto& stored = sb->getResourcesStored();
        const auto& maxStored = sb->getMaxResourcesStored();
        info["metal"] = stored.metal;
        info["oil"] = stored.oil;
        info["gold"] = stored.gold;
        info["metal_max"] = maxStored.metal;
        info["oil_max"] = maxStored.oil;
        info["gold_max"] = maxStored.gold;

        const auto& prod = sb->getProd();
        info["production_metal"] = prod.metal;
        info["production_oil"] = prod.oil;
        info["production_gold"] = prod.gold;

        const auto& needed = sb->getResourcesNeeded();
        info["needed_metal"] = needed.metal;
        info["needed_oil"] = needed.oil;
        info["needed_gold"] = needed.gold;

        info["energy_prod"] = sb->getEnergyProd();
        info["energy_need"] = sb->getEnergyNeed();
        info["energy_max_prod"] = sb->getMaxEnergyProd();
        info["energy_max_need"] = sb->getMaxEnergyNeed();
        info["human_prod"] = sb->getHumanProd();
        info["human_need"] = sb->getHumanNeed();

        // Building IDs in this sub-base
        Array bldg_ids;
        for (const auto* bldg : sb->getBuildings()) {
            bldg_ids.push_back(static_cast<int>(bldg->getId()));
        }
        info["building_count"] = bldg_ids.size();
        info["buildings"] = bldg_ids;

        result.push_back(info);
    }
    return result;
}

// ========== FOG OF WAR / VISIBILITY (Phase 14) ==========

bool GamePlayer::can_see_at(Vector2i pos) const {
    if (!player) return false;
    return player->canSeeAt(cPosition(pos.x, pos.y));
}

PackedInt32Array GamePlayer::get_scan_map_data() const {
    PackedInt32Array result;
    if (!player) return result;

    const auto& scanMap = player->getScanMap();
    auto raw = scanMap.getMap();
    result.resize(static_cast<int>(raw.size()));
    for (size_t i = 0; i < raw.size(); i++) {
        result[static_cast<int>(i)] = static_cast<int32_t>(raw[i]);
    }
    return result;
}

Vector2i GamePlayer::get_scan_map_size() const {
    if (!player) return Vector2i(0, 0);
    // The scan map size matches the game map size.
    // We can get it from the scan map data length and map width.
    const auto& scanMap = player->getScanMap();
    auto raw = scanMap.getMap();
    if (raw.empty()) return Vector2i(0, 0);

    // We need the map dimensions. The scan map is resized to match the map.
    // Since we don't have direct access to map here, we infer from the player's first unit
    // or we can use a simpler approach: the scan map stores size internally.
    // Actually, let's just return the data size and let GDScript use the map dimensions.
    // For convenience, we compute sqrt if it's square, otherwise GDScript uses map.get_size().
    int total = static_cast<int>(raw.size());
    return Vector2i(total, 1);  // GDScript should use game_map.get_size() for proper w/h
}
