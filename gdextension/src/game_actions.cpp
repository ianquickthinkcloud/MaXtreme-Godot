#include "game_actions.h"

#include <godot_cpp/variant/utility_functions.hpp>

// M.A.X.R. action includes
#include "game/data/model.h"
#include "game/data/map/map.h"
#include "game/data/player/player.h"
#include "game/data/units/unit.h"
#include "game/data/units/vehicle.h"
#include "game/data/units/building.h"
#include "game/data/units/unitdata.h"
#include "game/data/units/id.h"
#include "game/data/miningresource.h"
#include "game/data/resourcetype.h"
#include "game/logic/action/actionstartmove.h"
#include "game/logic/action/actionresumemove.h"
#include "game/logic/action/actionsetautomove.h"
#include "game/logic/action/actionattack.h"
#include "game/logic/action/actionchangesentry.h"
#include "game/logic/action/actionchangemanualfire.h"
#include "game/logic/action/actionminelayerstatus.h"
#include "game/logic/action/actionstartbuild.h"
#include "game/logic/action/actionfinishbuild.h"
#include "game/logic/action/actionchangebuildlist.h"
#include "game/logic/action/actionstartwork.h"
#include "game/logic/action/actionstop.h"
#include "game/logic/action/actionresourcedistribution.h"
#include "game/logic/action/actionchangeresearch.h"
#include "game/logic/action/actiontransfer.h"
#include "game/logic/action/actionload.h"
#include "game/logic/action/actionactivate.h"
#include "game/logic/action/actionrepairreload.h"
#include "game/logic/action/actionstealdisable.h"
#include "game/logic/action/actionclear.h"
#include "game/logic/action/actionselfdestroy.h"
#include "game/logic/action/actionchangeunitname.h"
#include "game/logic/action/actionupgradevehicle.h"
#include "game/logic/action/actionupgradebuilding.h"
#include "game/logic/action/actionendturn.h"
#include "game/logic/action/actionstartturn.h"
#include "game/logic/action/actionbuyupgrades.h"
#include "game/logic/endmoveaction.h"
#include "game/logic/movejob.h"
#include "utility/position.h"

using namespace godot;

// ========== BINDING ==========

void GameActions::_bind_methods() {
    // Movement
    ClassDB::bind_method(D_METHOD("move_unit", "unit_id", "path"), &GameActions::move_unit);
    ClassDB::bind_method(D_METHOD("resume_move", "unit_id"), &GameActions::resume_move);
    ClassDB::bind_method(D_METHOD("set_auto_move", "unit_id", "enabled"), &GameActions::set_auto_move);

    // Combat
    ClassDB::bind_method(D_METHOD("attack", "attacker_id", "target_pos", "target_unit_id"), &GameActions::attack, DEFVAL(-1));
    ClassDB::bind_method(D_METHOD("toggle_sentry", "unit_id"), &GameActions::toggle_sentry);
    ClassDB::bind_method(D_METHOD("toggle_manual_fire", "unit_id"), &GameActions::toggle_manual_fire);
    ClassDB::bind_method(D_METHOD("set_minelayer_status", "unit_id", "lay_mines", "clear_mines"), &GameActions::set_minelayer_status);

    // Construction
    ClassDB::bind_method(D_METHOD("start_build", "vehicle_id", "building_type_id", "build_speed", "build_pos"), &GameActions::start_build);
    ClassDB::bind_method(D_METHOD("finish_build", "unit_id", "escape_pos"), &GameActions::finish_build);
    ClassDB::bind_method(D_METHOD("change_build_list", "building_id", "build_list", "build_speed", "repeat"), &GameActions::change_build_list);

    // Production & Work
    ClassDB::bind_method(D_METHOD("start_work", "unit_id"), &GameActions::start_work);
    ClassDB::bind_method(D_METHOD("stop", "unit_id"), &GameActions::stop);
    ClassDB::bind_method(D_METHOD("set_resource_distribution", "building_id", "metal", "oil", "gold"), &GameActions::set_resource_distribution);
    ClassDB::bind_method(D_METHOD("change_research", "areas"), &GameActions::change_research);

    // Logistics
    ClassDB::bind_method(D_METHOD("transfer_resources", "source_id", "dest_id", "amount", "resource_type"), &GameActions::transfer_resources);
    ClassDB::bind_method(D_METHOD("load_unit", "loader_id", "vehicle_id"), &GameActions::load_unit);
    ClassDB::bind_method(D_METHOD("activate_unit", "container_id", "vehicle_id", "position"), &GameActions::activate_unit);
    ClassDB::bind_method(D_METHOD("repair_reload", "source_id", "target_id", "supply_type"), &GameActions::repair_reload);

    // Special
    ClassDB::bind_method(D_METHOD("steal_disable", "infiltrator_id", "target_id", "steal"), &GameActions::steal_disable);
    ClassDB::bind_method(D_METHOD("clear_area", "vehicle_id"), &GameActions::clear_area);
    ClassDB::bind_method(D_METHOD("self_destroy", "building_id"), &GameActions::self_destroy);
    ClassDB::bind_method(D_METHOD("rename_unit", "unit_id", "new_name"), &GameActions::rename_unit);
    ClassDB::bind_method(D_METHOD("upgrade_vehicle", "building_id", "vehicle_id"), &GameActions::upgrade_vehicle);
    ClassDB::bind_method(D_METHOD("upgrade_building", "building_id", "all"), &GameActions::upgrade_building);

    // Turn management
    ClassDB::bind_method(D_METHOD("end_turn"), &GameActions::end_turn);
    ClassDB::bind_method(D_METHOD("start_turn"), &GameActions::start_turn);
}

// ========== LIFECYCLE ==========

GameActions::GameActions() {}
GameActions::~GameActions() {}

void GameActions::set_internal_model(cModel* m) {
    model = m;
}

// ========== HELPERS ==========

cUnit* GameActions::find_unit(int unit_id) const {
    if (!model) return nullptr;
    for (const auto& player : model->getPlayerList()) {
        auto* v = player->getVehicleFromId(static_cast<unsigned int>(unit_id));
        if (v) return v;
        auto* b = player->getBuildingFromId(static_cast<unsigned int>(unit_id));
        if (b) return b;
    }
    return nullptr;
}

cVehicle* GameActions::find_vehicle(int unit_id) const {
    if (!model) return nullptr;
    for (const auto& player : model->getPlayerList()) {
        auto* v = player->getVehicleFromId(static_cast<unsigned int>(unit_id));
        if (v) return v;
    }
    return nullptr;
}

cBuilding* GameActions::find_building(int unit_id) const {
    if (!model) return nullptr;
    for (const auto& player : model->getPlayerList()) {
        auto* b = player->getBuildingFromId(static_cast<unsigned int>(unit_id));
        if (b) return b;
    }
    return nullptr;
}

cPlayer* GameActions::find_unit_owner(int unit_id) const {
    if (!model) return nullptr;
    for (const auto& player : model->getPlayerList()) {
        if (player->getVehicleFromId(static_cast<unsigned int>(unit_id))) return player.get();
        if (player->getBuildingFromId(static_cast<unsigned int>(unit_id))) return player.get();
    }
    return nullptr;
}

// ========== MOVEMENT ==========

bool GameActions::move_unit(int unit_id, PackedVector2Array path) {
    if (!model) return false;
    auto* vehicle = find_vehicle(unit_id);
    if (!vehicle) {
        UtilityFunctions::push_warning("[MaXtreme] move_unit: vehicle not found: ", unit_id);
        return false;
    }
    if (path.size() < 1) {
        UtilityFunctions::push_warning("[MaXtreme] move_unit: path is empty");
        return false;
    }

    // Convert PackedVector2Array to forward_list<cPosition> (reverse order for forward_list)
    std::forward_list<cPosition> cpath;
    for (int i = path.size() - 1; i >= 0; i--) {
        Vector2 p = path[i];
        cpath.push_front(cPosition(static_cast<int>(p.x), static_cast<int>(p.y)));
    }

    try {
        cActionStartMove action(*vehicle, cpath, eStart::Immediate, eStopOn::Never, cEndMoveAction::None());
        action.execute(*model);
        UtilityFunctions::print("[MaXtreme] move_unit: vehicle ", unit_id, " moving");
        return true;
    } catch (const std::exception& e) {
        UtilityFunctions::push_warning("[MaXtreme] move_unit failed: ", e.what());
        return false;
    }
}

bool GameActions::resume_move(int unit_id) {
    if (!model) return false;
    auto* vehicle = find_vehicle(unit_id);
    if (!vehicle) return false;

    try {
        cActionResumeMove action(*vehicle);
        action.execute(*model);
        return true;
    } catch (const std::exception& e) {
        UtilityFunctions::push_warning("[MaXtreme] resume_move failed: ", e.what());
        return false;
    }
}

bool GameActions::set_auto_move(int unit_id, bool enabled) {
    if (!model) return false;
    auto* vehicle = find_vehicle(unit_id);
    if (!vehicle) return false;

    try {
        cActionSetAutoMove action(*vehicle, enabled);
        action.execute(*model);
        return true;
    } catch (const std::exception& e) {
        UtilityFunctions::push_warning("[MaXtreme] set_auto_move failed: ", e.what());
        return false;
    }
}

// ========== COMBAT ==========

bool GameActions::attack(int attacker_id, Vector2i target_pos, int target_unit_id) {
    if (!model) return false;
    auto* aggressor = find_unit(attacker_id);
    if (!aggressor) {
        UtilityFunctions::push_warning("[MaXtreme] attack: attacker not found: ", attacker_id);
        return false;
    }

    cPosition targetPosition(target_pos.x, target_pos.y);
    cUnit* target = (target_unit_id >= 0) ? find_unit(target_unit_id) : nullptr;

    try {
        cActionAttack action(*aggressor, targetPosition, target);
        action.execute(*model);
        UtilityFunctions::print("[MaXtreme] attack: unit ", attacker_id, " attacks at (", target_pos.x, ",", target_pos.y, ")");
        return true;
    } catch (const std::exception& e) {
        UtilityFunctions::push_warning("[MaXtreme] attack failed: ", e.what());
        return false;
    }
}

bool GameActions::toggle_sentry(int unit_id) {
    if (!model) return false;
    auto* unit = find_unit(unit_id);
    if (!unit) return false;

    try {
        cActionChangeSentry action(*unit);
        action.execute(*model);
        return true;
    } catch (const std::exception& e) {
        UtilityFunctions::push_warning("[MaXtreme] toggle_sentry failed: ", e.what());
        return false;
    }
}

bool GameActions::toggle_manual_fire(int unit_id) {
    if (!model) return false;
    auto* unit = find_unit(unit_id);
    if (!unit) return false;

    try {
        cActionChangeManualFire action(*unit);
        action.execute(*model);
        return true;
    } catch (const std::exception& e) {
        UtilityFunctions::push_warning("[MaXtreme] toggle_manual_fire failed: ", e.what());
        return false;
    }
}

bool GameActions::set_minelayer_status(int unit_id, bool lay_mines, bool clear_mines) {
    if (!model) return false;
    auto* vehicle = find_vehicle(unit_id);
    if (!vehicle) return false;

    try {
        cActionMinelayerStatus action(*vehicle, lay_mines, clear_mines);
        action.execute(*model);
        return true;
    } catch (const std::exception& e) {
        UtilityFunctions::push_warning("[MaXtreme] set_minelayer_status failed: ", e.what());
        return false;
    }
}

// ========== CONSTRUCTION ==========

bool GameActions::start_build(int vehicle_id, String building_type_id, int build_speed, Vector2i build_pos) {
    if (!model) return false;
    auto* vehicle = find_vehicle(vehicle_id);
    if (!vehicle) {
        UtilityFunctions::push_warning("[MaXtreme] start_build: vehicle not found: ", vehicle_id);
        return false;
    }

    // Parse building type ID from string "firstPart.secondPart"
    std::string idStr = building_type_id.utf8().get_data();
    sID buildingID;
    auto dotPos = idStr.find('.');
    if (dotPos != std::string::npos) {
        buildingID.firstPart = std::stoi(idStr.substr(0, dotPos));
        buildingID.secondPart = std::stoi(idStr.substr(dotPos + 1));
    }

    cPosition buildPosition(build_pos.x, build_pos.y);

    try {
        cActionStartBuild action(*vehicle, buildingID, build_speed, buildPosition);
        action.execute(*model);
        UtilityFunctions::print("[MaXtreme] start_build: vehicle ", vehicle_id, " building at (", build_pos.x, ",", build_pos.y, ")");
        return true;
    } catch (const std::exception& e) {
        UtilityFunctions::push_warning("[MaXtreme] start_build failed: ", e.what());
        return false;
    }
}

bool GameActions::finish_build(int unit_id, Vector2i escape_pos) {
    if (!model) return false;
    auto* unit = find_unit(unit_id);
    if (!unit) return false;

    try {
        cActionFinishBuild action(*unit, cPosition(escape_pos.x, escape_pos.y));
        action.execute(*model);
        return true;
    } catch (const std::exception& e) {
        UtilityFunctions::push_warning("[MaXtreme] finish_build failed: ", e.what());
        return false;
    }
}

bool GameActions::change_build_list(int building_id, Array build_list, int build_speed, bool repeat) {
    if (!model) return false;
    auto* building = find_building(building_id);
    if (!building) return false;

    std::vector<sID> idList;
    for (int i = 0; i < build_list.size(); i++) {
        String idStr = build_list[i];
        std::string s = idStr.utf8().get_data();
        sID id;
        auto dotPos = s.find('.');
        if (dotPos != std::string::npos) {
            id.firstPart = std::stoi(s.substr(0, dotPos));
            id.secondPart = std::stoi(s.substr(dotPos + 1));
        }
        idList.push_back(id);
    }

    try {
        cActionChangeBuildList action(*building, idList, build_speed, repeat);
        action.execute(*model);
        return true;
    } catch (const std::exception& e) {
        UtilityFunctions::push_warning("[MaXtreme] change_build_list failed: ", e.what());
        return false;
    }
}

// ========== PRODUCTION & WORK ==========

bool GameActions::start_work(int unit_id) {
    if (!model) return false;
    auto* unit = find_unit(unit_id);
    if (!unit) return false;

    try {
        cActionStartWork action(*unit);
        action.execute(*model);
        UtilityFunctions::print("[MaXtreme] start_work: unit ", unit_id);
        return true;
    } catch (const std::exception& e) {
        UtilityFunctions::push_warning("[MaXtreme] start_work failed: ", e.what());
        return false;
    }
}

bool GameActions::stop(int unit_id) {
    if (!model) return false;
    auto* unit = find_unit(unit_id);
    if (!unit) return false;

    try {
        cActionStop action(*unit);
        action.execute(*model);
        return true;
    } catch (const std::exception& e) {
        UtilityFunctions::push_warning("[MaXtreme] stop failed: ", e.what());
        return false;
    }
}

bool GameActions::set_resource_distribution(int building_id, int metal, int oil, int gold) {
    if (!model) return false;
    auto* building = find_building(building_id);
    if (!building) return false;

    sMiningResource res;
    res.metal = metal;
    res.oil = oil;
    res.gold = gold;

    try {
        cActionResourceDistribution action(*building, res);
        action.execute(*model);
        return true;
    } catch (const std::exception& e) {
        UtilityFunctions::push_warning("[MaXtreme] set_resource_distribution failed: ", e.what());
        return false;
    }
}

bool GameActions::change_research(Array areas) {
    if (!model) return false;

    std::array<int, cResearch::kNrResearchAreas> researchAreas{};
    for (int i = 0; i < std::min(static_cast<int>(areas.size()), static_cast<int>(cResearch::kNrResearchAreas)); i++) {
        researchAreas[i] = static_cast<int>(areas[i]);
    }

    try {
        cActionChangeResearch action(researchAreas);
        action.execute(*model);
        return true;
    } catch (const std::exception& e) {
        UtilityFunctions::push_warning("[MaXtreme] change_research failed: ", e.what());
        return false;
    }
}

// ========== LOGISTICS ==========

bool GameActions::transfer_resources(int source_id, int dest_id, int amount, String resource_type) {
    if (!model) return false;
    auto* source = find_unit(source_id);
    auto* dest = find_unit(dest_id);
    if (!source || !dest) return false;

    eResourceType resType = eResourceType::None;
    std::string rt = resource_type.utf8().get_data();
    if (rt == "metal") resType = eResourceType::Metal;
    else if (rt == "oil") resType = eResourceType::Oil;
    else if (rt == "gold") resType = eResourceType::Gold;

    try {
        cActionTransfer action(*source, *dest, amount, resType);
        action.execute(*model);
        return true;
    } catch (const std::exception& e) {
        UtilityFunctions::push_warning("[MaXtreme] transfer_resources failed: ", e.what());
        return false;
    }
}

bool GameActions::load_unit(int loader_id, int vehicle_id) {
    if (!model) return false;
    auto* loader = find_unit(loader_id);
    auto* vehicle = find_vehicle(vehicle_id);
    if (!loader || !vehicle) return false;

    try {
        cActionLoad action(*loader, *vehicle);
        action.execute(*model);
        return true;
    } catch (const std::exception& e) {
        UtilityFunctions::push_warning("[MaXtreme] load_unit failed: ", e.what());
        return false;
    }
}

bool GameActions::activate_unit(int container_id, int vehicle_id, Vector2i position) {
    if (!model) return false;
    auto* container = find_unit(container_id);
    auto* vehicle = find_vehicle(vehicle_id);
    if (!container || !vehicle) return false;

    try {
        cActionActivate action(*container, *vehicle, cPosition(position.x, position.y));
        action.execute(*model);
        return true;
    } catch (const std::exception& e) {
        UtilityFunctions::push_warning("[MaXtreme] activate_unit failed: ", e.what());
        return false;
    }
}

bool GameActions::repair_reload(int source_id, int target_id, String supply_type) {
    if (!model) return false;
    auto* source = find_unit(source_id);
    auto* target = find_unit(target_id);
    if (!source || !target) return false;

    eSupplyType st = eSupplyType::REARM;
    std::string s = supply_type.utf8().get_data();
    if (s == "repair") st = eSupplyType::REPAIR;

    try {
        cActionRepairReload action(*source, *target, st);
        action.execute(*model);
        return true;
    } catch (const std::exception& e) {
        UtilityFunctions::push_warning("[MaXtreme] repair_reload failed: ", e.what());
        return false;
    }
}

// ========== SPECIAL ==========

bool GameActions::steal_disable(int infiltrator_id, int target_id, bool steal) {
    if (!model) return false;
    auto* infiltrator = find_vehicle(infiltrator_id);
    auto* target = find_unit(target_id);
    if (!infiltrator || !target) return false;

    try {
        cActionStealDisable action(*infiltrator, *target, steal);
        action.execute(*model);
        return true;
    } catch (const std::exception& e) {
        UtilityFunctions::push_warning("[MaXtreme] steal_disable failed: ", e.what());
        return false;
    }
}

bool GameActions::clear_area(int vehicle_id) {
    if (!model) return false;
    auto* vehicle = find_vehicle(vehicle_id);
    if (!vehicle) return false;

    try {
        cActionClear action(*vehicle);
        action.execute(*model);
        return true;
    } catch (const std::exception& e) {
        UtilityFunctions::push_warning("[MaXtreme] clear_area failed: ", e.what());
        return false;
    }
}

bool GameActions::self_destroy(int building_id) {
    if (!model) return false;
    auto* building = find_building(building_id);
    if (!building) return false;

    try {
        cActionSelfDestroy action(*building);
        action.execute(*model);
        return true;
    } catch (const std::exception& e) {
        UtilityFunctions::push_warning("[MaXtreme] self_destroy failed: ", e.what());
        return false;
    }
}

bool GameActions::rename_unit(int unit_id, String new_name) {
    if (!model) return false;
    auto* unit = find_unit(unit_id);
    if (!unit) return false;

    std::string name = new_name.utf8().get_data();
    try {
        cActionChangeUnitName action(*unit, std::move(name));
        action.execute(*model);
        return true;
    } catch (const std::exception& e) {
        UtilityFunctions::push_warning("[MaXtreme] rename_unit failed: ", e.what());
        return false;
    }
}

bool GameActions::upgrade_vehicle(int building_id, int vehicle_id) {
    if (!model) return false;
    auto* building = find_building(building_id);
    if (!building) return false;

    cVehicle* vehicle = (vehicle_id >= 0) ? find_vehicle(vehicle_id) : nullptr;

    try {
        cActionUpgradeVehicle action(*building, vehicle);
        action.execute(*model);
        return true;
    } catch (const std::exception& e) {
        UtilityFunctions::push_warning("[MaXtreme] upgrade_vehicle failed: ", e.what());
        return false;
    }
}

bool GameActions::upgrade_building(int building_id, bool all) {
    if (!model) return false;
    auto* building = find_building(building_id);
    if (!building) return false;

    try {
        cActionUpgradeBuilding action(*building, all);
        action.execute(*model);
        return true;
    } catch (const std::exception& e) {
        UtilityFunctions::push_warning("[MaXtreme] upgrade_building failed: ", e.what());
        return false;
    }
}

// ========== TURN MANAGEMENT ==========

bool GameActions::end_turn() {
    if (!model) return false;

    try {
        cActionEndTurn action;
        action.execute(*model);
        UtilityFunctions::print("[MaXtreme] end_turn executed");
        return true;
    } catch (const std::exception& e) {
        UtilityFunctions::push_warning("[MaXtreme] end_turn failed: ", e.what());
        return false;
    }
}

bool GameActions::start_turn() {
    if (!model) return false;

    try {
        cActionStartTurn action;
        action.execute(*model);
        UtilityFunctions::print("[MaXtreme] start_turn executed");
        return true;
    } catch (const std::exception& e) {
        UtilityFunctions::push_warning("[MaXtreme] start_turn failed: ", e.what());
        return false;
    }
}
