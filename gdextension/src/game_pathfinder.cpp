#include "game_pathfinder.h"

#include <godot_cpp/variant/utility_functions.hpp>

#include "game/data/model.h"
#include "game/data/map/map.h"
#include "game/data/map/mapview.h"
#include "game/data/player/player.h"
#include "game/data/units/vehicle.h"
#include "game/data/units/building.h"
#include "game/logic/pathcalculator.h"
#include "utility/position.h"

#include <queue>
#include <vector>
#include <unordered_map>

using namespace godot;

void GamePathfinder::_bind_methods() {
    // Path calculation
    ClassDB::bind_method(D_METHOD("calculate_path", "unit_id", "target"), &GamePathfinder::calculate_path);
    ClassDB::bind_method(D_METHOD("get_path_cost", "unit_id", "path"), &GamePathfinder::get_path_cost);
    ClassDB::bind_method(D_METHOD("get_step_cost", "unit_id", "from", "to"), &GamePathfinder::get_step_cost);

    // Movement range
    ClassDB::bind_method(D_METHOD("get_reachable_tiles", "unit_id"), &GamePathfinder::get_reachable_tiles);
    ClassDB::bind_method(D_METHOD("get_reachable_positions", "unit_id"), &GamePathfinder::get_reachable_positions);
    ClassDB::bind_method(D_METHOD("is_tile_reachable", "unit_id", "target"), &GamePathfinder::is_tile_reachable);

    // Attack range
    ClassDB::bind_method(D_METHOD("get_enemies_in_range", "unit_id"), &GamePathfinder::get_enemies_in_range);
    ClassDB::bind_method(D_METHOD("get_attack_range_tiles", "unit_id"), &GamePathfinder::get_attack_range_tiles);
    ClassDB::bind_method(D_METHOD("can_attack_position", "unit_id", "target"), &GamePathfinder::can_attack_position);
    ClassDB::bind_method(D_METHOD("preview_attack", "attacker_id", "target_id"), &GamePathfinder::preview_attack);

    // Utility
    ClassDB::bind_method(D_METHOD("get_movement_points", "unit_id"), &GamePathfinder::get_movement_points);
    ClassDB::bind_method(D_METHOD("get_movement_points_max", "unit_id"), &GamePathfinder::get_movement_points_max);
}

GamePathfinder::GamePathfinder() {}
GamePathfinder::~GamePathfinder() {}

void GamePathfinder::set_internal_model(cModel* m) {
    model = m;
}

// --- Helper: find a vehicle by ID across all players ---
static cVehicle* find_vehicle(cModel* model, int unit_id) {
    if (!model) return nullptr;
    for (auto& player : model->getPlayerList()) {
        auto* v = player->getVehicleFromId(static_cast<unsigned int>(unit_id));
        if (v) return v;
    }
    return nullptr;
}

// --- Helper: find the owner player of a vehicle ---
static std::shared_ptr<cPlayer> find_owner(cModel* model, const cVehicle* vehicle) {
    if (!model || !vehicle || !vehicle->getOwner()) return nullptr;
    int ownerId = vehicle->getOwner()->getId();
    for (auto& player : model->getPlayerList()) {
        if (player->getId() == ownerId) return player;
    }
    return nullptr;
}

// ============================================================
// PATH CALCULATION
// ============================================================

PackedVector2Array GamePathfinder::calculate_path(int unit_id, Vector2i target) const {
    PackedVector2Array result;
    if (!model) return result;

    auto* vehicle = find_vehicle(model, unit_id);
    if (!vehicle) {
        UtilityFunctions::push_warning("[Pathfinder] Vehicle not found: ", unit_id);
        return result;
    }

    auto owner = find_owner(model, vehicle);
    if (!owner) return result;

    // Create an omniscient map view (nullptr player = sees everything)
    // We don't have fog of war in the prototype yet
    cMapView mapView(model->getMap(), nullptr);

    // Calculate A* path
    cPosition dest(target.x, target.y);
    cPathCalculator pathCalc(*vehicle, mapView, dest, nullptr);
    auto path = pathCalc.calcPath();

    // Convert forward_list to PackedVector2Array
    for (const auto& pos : path) {
        result.push_back(Vector2(static_cast<float>(pos.x()), static_cast<float>(pos.y())));
    }

    return result;
}

int GamePathfinder::get_path_cost(int unit_id, PackedVector2Array path) const {
    if (!model || path.size() < 2) return -1;

    auto* vehicle = find_vehicle(model, unit_id);
    if (!vehicle) return -1;

    auto mapPtr = model->getMap();
    if (!mapPtr) return -1;

    int totalCost = 0;
    for (int i = 0; i < path.size() - 1; i++) {
        cPosition from(static_cast<int>(path[i].x), static_cast<int>(path[i].y));
        cPosition to(static_cast<int>(path[i + 1].x), static_cast<int>(path[i + 1].y));
        int cost = cPathCalculator::calcNextCost(from, to, vehicle, mapPtr.get());
        if (cost <= 0) return -1; // impassable
        totalCost += cost;
    }

    return totalCost;
}

int GamePathfinder::get_step_cost(int unit_id, Vector2i from, Vector2i to) const {
    if (!model) return -1;

    auto* vehicle = find_vehicle(model, unit_id);
    if (!vehicle) return -1;

    auto mapPtr = model->getMap();
    if (!mapPtr) return -1;

    cPosition src(from.x, from.y);
    cPosition dst(to.x, to.y);
    return cPathCalculator::calcNextCost(src, dst, vehicle, mapPtr.get());
}

// ============================================================
// MOVEMENT RANGE (Dijkstra flood-fill)
// ============================================================

// Internal structure for the Dijkstra expansion
struct ReachableNode {
    int x, y;
    int cost;
    bool operator>(const ReachableNode& other) const { return cost > other.cost; }
};

Array GamePathfinder::get_reachable_tiles(int unit_id) const {
    Array result;
    if (!model) return result;

    auto* vehicle = find_vehicle(model, unit_id);
    if (!vehicle) return result;

    auto owner = find_owner(model, vehicle);
    if (!owner) return result;

    auto mapPtr = model->getMap();
    if (!mapPtr) return result;

    int speed = vehicle->data.getSpeed();
    if (speed <= 0) return result;

    auto mapSize = mapPtr->getSize();
    int w = mapSize.x();
    int h = mapSize.y();

    // Use the raw map (not MapView) so we don't filter by visibility
    // (we don't have fog of war yet in the prototype)
    auto* rawMap = mapPtr.get();

    // Dijkstra flood-fill from the unit's position
    auto startPos = vehicle->getPosition();

    // Cost grid: -1 means unvisited
    std::vector<int> costGrid(w * h, -1);
    costGrid[startPos.y() * w + startPos.x()] = 0;

    // Priority queue (min-heap by cost)
    std::priority_queue<ReachableNode, std::vector<ReachableNode>, std::greater<ReachableNode>> pq;
    pq.push({startPos.x(), startPos.y(), 0});

    // 8 directions
    static const int dx[] = {-1, 0, 1, -1, 1, -1, 0, 1};
    static const int dy[] = {-1, -1, -1, 0, 0, 1, 1, 1};

    while (!pq.empty()) {
        auto current = pq.top();
        pq.pop();

        // Skip if we already found a cheaper path
        int idx = current.y * w + current.x;
        if (current.cost > costGrid[idx]) continue;

        // Expand in 8 directions
        for (int d = 0; d < 8; d++) {
            int nx = current.x + dx[d];
            int ny = current.y + dy[d];

            // Bounds check
            if (nx < 0 || nx >= w || ny < 0 || ny >= h) continue;

            cPosition nextPos(nx, ny);
            cPosition curPos(current.x, current.y);

            // Check passability using the raw map (no visibility filter)
            if (!rawMap->possiblePlace(*vehicle, nextPos, false)) continue;

            // Calculate movement cost for this step
            int stepCost = cPathCalculator::calcNextCost(curPos, nextPos, vehicle, rawMap);
            if (stepCost <= 0) continue;

            int newCost = current.cost + stepCost;
            if (newCost > speed) continue;

            int nidx = ny * w + nx;
            if (costGrid[nidx] == -1 || newCost < costGrid[nidx]) {
                costGrid[nidx] = newCost;
                pq.push({nx, ny, newCost});
            }
        }
    }

    // Build result array (skip the start position itself)
    for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
            int cost = costGrid[y * w + x];
            if (cost > 0) { // cost == 0 is the start position
                Dictionary tile;
                tile["pos"] = Vector2i(x, y);
                tile["cost"] = cost;
                result.push_back(tile);
            }
        }
    }

    return result;
}

PackedVector2Array GamePathfinder::get_reachable_positions(int unit_id) const {
    PackedVector2Array result;
    Array tiles = get_reachable_tiles(unit_id);
    for (int i = 0; i < tiles.size(); i++) {
        Dictionary tile = tiles[i];
        Vector2i pos = tile["pos"];
        result.push_back(Vector2(static_cast<float>(pos.x), static_cast<float>(pos.y)));
    }
    return result;
}

bool GamePathfinder::is_tile_reachable(int unit_id, Vector2i target) const {
    if (!model) return false;

    // Quick check: calculate direct path and see if cost is within range
    auto* vehicle = find_vehicle(model, unit_id);
    if (!vehicle) return false;

    auto path = calculate_path(unit_id, target);
    if (path.is_empty()) return false;

    int cost = get_path_cost(unit_id, path);
    return cost >= 0 && cost <= vehicle->data.getSpeed();
}

// ============================================================
// ATTACK RANGE
// ============================================================

Array GamePathfinder::get_enemies_in_range(int unit_id) const {
    Array result;
    if (!model) return result;

    auto* vehicle = find_vehicle(model, unit_id);
    if (!vehicle) return result;

    // Check if unit can attack at all
    const auto& sd = vehicle->getStaticUnitData();
    if (sd.canAttack == 0) return result;
    if (vehicle->data.getShots() <= 0 || vehicle->data.getAmmo() <= 0) return result;
    if (vehicle->isAttacking()) return result;

    int range = vehicle->data.getRange();
    if (range <= 0) return result;
    int rangeSq = range * range;

    auto ownerPtr = vehicle->getOwner();
    int ownerId = ownerPtr ? ownerPtr->getId() : -1;

    const auto& myPos = vehicle->getPosition();

    // Scan all players for enemies in range
    for (auto& player : model->getPlayerList()) {
        if (player->getId() == ownerId) continue; // Skip own units

        // Check vehicles
        for (const auto& v : player->getVehicles()) {
            const auto& vpos = v->getPosition();
            int dx = vpos.x() - myPos.x();
            int dy = vpos.y() - myPos.y();
            int distSq = dx * dx + dy * dy;
            if (distSq <= rangeSq) {
                // Check attack type compatibility
                bool canTarget = false;
                if (sd.factorAir > 0 && v->getStaticUnitData().factorAir > 0) {
                    // Air unit targeting air unit
                    canTarget = (sd.canAttack & 1) != 0; // Air flag
                } else if (v->getStaticUnitData().factorSea > 0 && v->getStaticUnitData().factorGround == 0) {
                    canTarget = (sd.canAttack & 2) != 0; // Sea flag
                } else {
                    canTarget = (sd.canAttack & 4) != 0; // Ground flag
                }

                if (canTarget) {
                    Dictionary entry;
                    entry["id"] = static_cast<int>(v->getId());
                    entry["pos"] = Vector2i(vpos.x(), vpos.y());
                    entry["owner"] = player->getId();
                    entry["distance"] = distSq;
                    entry["is_vehicle"] = true;
                    result.push_back(entry);
                }
            }
        }

        // Check buildings
        for (const auto& b : player->getBuildings()) {
            const auto& bpos = b->getPosition();
            int dx = bpos.x() - myPos.x();
            int dy = bpos.y() - myPos.y();
            int distSq = dx * dx + dy * dy;
            if (distSq <= rangeSq) {
                if ((sd.canAttack & 4) != 0) { // Ground flag for buildings
                    Dictionary entry;
                    entry["id"] = static_cast<int>(b->getId());
                    entry["pos"] = Vector2i(bpos.x(), bpos.y());
                    entry["owner"] = player->getId();
                    entry["distance"] = distSq;
                    entry["is_vehicle"] = false;
                    result.push_back(entry);
                }
            }
        }
    }

    return result;
}

PackedVector2Array GamePathfinder::get_attack_range_tiles(int unit_id) const {
    PackedVector2Array result;
    if (!model) return result;

    auto* vehicle = find_vehicle(model, unit_id);
    if (!vehicle) return result;

    int range = vehicle->data.getRange();
    if (range <= 0) return result;

    auto mapPtr = model->getMap();
    if (!mapPtr) return result;
    auto mapSize = mapPtr->getSize();

    const auto& pos = vehicle->getPosition();
    int rangeSq = range * range;

    // Iterate over a bounding box around the unit
    for (int y = pos.y() - range; y <= pos.y() + range; y++) {
        for (int x = pos.x() - range; x <= pos.x() + range; x++) {
            if (x < 0 || x >= mapSize.x() || y < 0 || y >= mapSize.y()) continue;
            int dx = x - pos.x();
            int dy = y - pos.y();
            if (dx * dx + dy * dy <= rangeSq) {
                result.push_back(Vector2(static_cast<float>(x), static_cast<float>(y)));
            }
        }
    }

    return result;
}

bool GamePathfinder::can_attack_position(int unit_id, Vector2i target) const {
    if (!model) return false;

    auto* vehicle = find_vehicle(model, unit_id);
    if (!vehicle) return false;

    const auto& sd = vehicle->getStaticUnitData();
    if (sd.canAttack == 0) return false;
    if (vehicle->data.getShots() <= 0 || vehicle->data.getAmmo() <= 0) return false;
    if (vehicle->isAttacking()) return false;

    int range = vehicle->data.getRange();
    if (range <= 0) return false;

    const auto& pos = vehicle->getPosition();
    int dx = target.x - pos.x();
    int dy = target.y - pos.y();
    return (dx * dx + dy * dy) <= (range * range);
}

Dictionary GamePathfinder::preview_attack(int attacker_id, int target_id) const {
    Dictionary result;
    result["damage"] = 0;
    result["target_hp_after"] = 0;
    result["will_destroy"] = false;

    if (!model) return result;

    auto* attacker = find_vehicle(model, attacker_id);
    if (!attacker) return result;

    // Find target (could be vehicle or building)
    cUnit* target = nullptr;
    for (auto& player : model->getPlayerList()) {
        auto* v = player->getVehicleFromId(static_cast<unsigned int>(target_id));
        if (v) { target = v; break; }
        auto* b = player->getBuildingFromId(static_cast<unsigned int>(target_id));
        if (b) { target = b; break; }
    }
    if (!target) return result;

    // Damage formula: max(1, damage - armor)
    int rawDamage = attacker->data.getDamage();
    int armor = target->data.getArmor();
    int finalDamage = std::max(1, rawDamage - armor);
    int hpAfter = std::max(0, target->data.getHitpoints() - finalDamage);

    result["damage"] = finalDamage;
    result["raw_damage"] = rawDamage;
    result["target_armor"] = armor;
    result["target_hp_before"] = target->data.getHitpoints();
    result["target_hp_after"] = hpAfter;
    result["will_destroy"] = (hpAfter <= 0);

    return result;
}

// ============================================================
// UTILITY
// ============================================================

int GamePathfinder::get_movement_points(int unit_id) const {
    if (!model) return 0;
    auto* vehicle = find_vehicle(model, unit_id);
    if (!vehicle) return 0;
    return vehicle->data.getSpeed();
}

int GamePathfinder::get_movement_points_max(int unit_id) const {
    if (!model) return 0;
    auto* vehicle = find_vehicle(model, unit_id);
    if (!vehicle) return 0;
    return vehicle->data.getSpeedMax();
}
