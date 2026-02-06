#include "game_setup.h"

#include <godot_cpp/variant/utility_functions.hpp>

#include "game/data/model.h"
#include "game/data/map/map.h"
#include "game/data/gamesettings.h"
#include "game/data/player/player.h"
#include "game/data/player/playerbasicdata.h"
#include "game/data/player/playersettings.h"
#include "game/data/units/unitdata.h"
#include "game/data/units/id.h"
#include "game/data/units/landingunit.h"
#include "game/data/units/vehicle.h"
#include "game/data/units/building.h"
#include "game/startup/initplayerdata.h"
#include "utility/position.h"
#include "utility/color.h"
#include "utility/log.h"
#include "settings.h"

#include <cstdio>
#include <cstring>
#include <fstream>

using namespace godot;

// ========== BINDING ==========

void GameSetup::_bind_methods() {
    // GameSetup is used internally by GameEngine; no direct GDScript bindings needed
}

GameSetup::GameSetup() {}
GameSetup::~GameSetup() {}

// ========== WRL MAP FILE CREATION ==========

bool GameSetup::write_wrl_file(const std::filesystem::path& path, int size) {
    // Create parent directories if needed
    if (path.has_parent_path()) {
        std::error_code ec;
        std::filesystem::create_directories(path.parent_path(), ec);
        if (ec) {
            UtilityFunctions::push_error("[MaXtreme] Cannot create directory: ", String(path.parent_path().string().c_str()));
            return false;
        }
    }

    std::ofstream file(path, std::ios::binary);
    if (!file.is_open()) {
        UtilityFunctions::push_error("[MaXtreme] Cannot create WRL file: ", String(path.string().c_str()));
        return false;
    }

    // WRL format:
    // 3 bytes: "WRL" magic
    // 2 bytes: padding (0x00)
    // 2 bytes LE: width
    // 2 bytes LE: height
    // width*height bytes: minimap data (all zeros)
    // width*height*2 bytes: tile data (LE16 each, all terrain 0 = ground)
    // 2 bytes LE: number of terrains
    // numTerrains * 64 * 64 bytes: terrain graphics (dummy data)
    // 256 * 3 bytes: palette (dummy data)
    // numTerrains bytes: terrain info (0 = normal ground)

    int numTerrains = 1; // Just one terrain type: ground

    // Magic
    file.write("WRL", 3);

    // 2 bytes padding
    uint8_t padding[2] = {0, 0};
    file.write(reinterpret_cast<const char*>(padding), 2);

    // Width and Height (LE16)
    uint16_t w = static_cast<uint16_t>(size);
    uint16_t h = static_cast<uint16_t>(size);
    file.write(reinterpret_cast<const char*>(&w), 2);
    file.write(reinterpret_cast<const char*>(&h), 2);

    // Minimap data (size*size bytes, all zero)
    std::vector<uint8_t> minimap(static_cast<size_t>(size) * size, 0);
    file.write(reinterpret_cast<const char*>(minimap.data()), minimap.size());

    // Tile data (size*size * 2 bytes, all terrain index 0)
    std::vector<uint16_t> tiles(static_cast<size_t>(size) * size, 0);
    file.write(reinterpret_cast<const char*>(tiles.data()), tiles.size() * 2);

    // Number of terrains (LE16)
    uint16_t nt = static_cast<uint16_t>(numTerrains);
    file.write(reinterpret_cast<const char*>(&nt), 2);

    // Terrain graphics: numTerrains * 64 * 64 bytes (dummy green-ish color)
    std::vector<uint8_t> terrainGfx(static_cast<size_t>(numTerrains) * 64 * 64, 32);
    file.write(reinterpret_cast<const char*>(terrainGfx.data()), terrainGfx.size());

    // Palette: 256 * 3 bytes (simple grayscale)
    std::vector<uint8_t> palette(256 * 3);
    for (int i = 0; i < 256; i++) {
        palette[i * 3 + 0] = static_cast<uint8_t>(i); // R
        palette[i * 3 + 1] = static_cast<uint8_t>(i); // G
        palette[i * 3 + 2] = static_cast<uint8_t>(i); // B
    }
    file.write(reinterpret_cast<const char*>(palette.data()), palette.size());

    // Terrain info: numTerrains bytes (0 = normal ground for all)
    std::vector<uint8_t> terrainInfo(numTerrains, 0);
    file.write(reinterpret_cast<const char*>(terrainInfo.data()), terrainInfo.size());

    file.close();
    return true;
}

std::shared_ptr<cStaticMap> GameSetup::create_and_load_flat_map(int size) {
    // Write a temporary WRL file
    auto tmpDir = std::filesystem::temp_directory_path() / "maxtreme";
    auto mapPath = tmpDir / "test_map.wrl";

    if (!write_wrl_file(mapPath, size)) {
        return nullptr;
    }

    // Update settings to use our temp directory as the maps path
    // The loadMap function prepends getMapsPath() to the filename
    // We need to load from an absolute path, so let's work around it:
    // Create the file in the settings maps path location
    auto mapsDir = cSettings::getInstance().getMapsPath();
    std::error_code ec;
    std::filesystem::create_directories(mapsDir, ec);

    auto mapFilePath = mapsDir / "test_map.wrl";
    if (!write_wrl_file(mapFilePath, size)) {
        // Fall back to temp dir approach
        UtilityFunctions::push_warning("[MaXtreme] Could not write to maps dir, trying temp dir");
    }

    auto staticMap = std::make_shared<cStaticMap>();
    if (staticMap->loadMap("test_map.wrl")) {
        UtilityFunctions::print("[MaXtreme]   Map loaded: ", size, "x", size, " flat ground");
        return staticMap;
    }

    // If maps dir didn't work, try loading from a full path by writing to a known location
    UtilityFunctions::push_error("[MaXtreme] Failed to load map from: ", String(mapFilePath.string().c_str()));
    return nullptr;
}

// ========== TEST UNIT DATA ==========

std::shared_ptr<cUnitsData> GameSetup::create_test_units_data() {
    auto unitsData = std::make_shared<cUnitsData>();

    // --- Vehicle 0: Constructor ---
    {
        cStaticUnitData sd;
        sd.ID = sID(0, 0);
        sd.setDefaultName(std::string("Constructor"));
        sd.setDefaultDescription(std::string("Mobile construction vehicle."));
        sd.canBuild = "big,small";
        sd.surfacePosition = eSurfacePosition::Ground;
        sd.vehicleData.canBuildPath = false;

        cDynamicUnitData dd;
        dd.setId(sID(0, 0));
        dd.setHitpointsMax(24); dd.setHitpoints(24);
        dd.setSpeedMax(12); dd.setSpeed(12);
        dd.setScan(5); dd.setRange(0);
        dd.setArmor(6); dd.setDamage(0);
        dd.setShotsMax(0); dd.setShots(0);
        dd.setAmmoMax(0); dd.setAmmo(0);
        dd.setBuildCost(12);

        unitsData->addData(sd);
        unitsData->addData(dd);
    }

    // --- Vehicle 1: Tank ---
    {
        cStaticUnitData sd;
        sd.ID = sID(0, 1);
        sd.setDefaultName(std::string("Tank"));
        sd.setDefaultDescription(std::string("Standard combat vehicle."));
        sd.canAttack = 5;
        sd.surfacePosition = eSurfacePosition::Ground;
        sd.factorGround = 1.0f;
        sd.factorSea = 0.5f;
        sd.factorCoast = 0.8f;
        sd.muzzleType = eMuzzleType::Big;

        cDynamicUnitData dd;
        dd.setId(sID(0, 1));
        dd.setHitpointsMax(24); dd.setHitpoints(24);
        dd.setSpeedMax(12); dd.setSpeed(12);
        dd.setScan(7); dd.setRange(5);
        dd.setArmor(9); dd.setDamage(14);
        dd.setShotsMax(1); dd.setShots(1);
        dd.setAmmoMax(6); dd.setAmmo(6);
        dd.setBuildCost(12);

        unitsData->addData(sd);
        unitsData->addData(dd);
    }

    // --- Vehicle 2: Alien Assault ---
    {
        cStaticUnitData sd;
        sd.ID = sID(0, 2);
        sd.setDefaultName(std::string("Alien Assault"));
        sd.setDefaultDescription(std::string("Alien assault unit."));
        sd.canAttack = 5;
        sd.surfacePosition = eSurfacePosition::Ground;
        sd.isAlien = true;
        sd.factorGround = 1.0f;
        sd.muzzleType = eMuzzleType::Small;

        cDynamicUnitData dd;
        dd.setId(sID(0, 2));
        dd.setHitpointsMax(16); dd.setHitpoints(16);
        dd.setSpeedMax(8); dd.setSpeed(8);
        dd.setScan(5); dd.setRange(3);
        dd.setArmor(4); dd.setDamage(8);
        dd.setShotsMax(1); dd.setShots(1);
        dd.setAmmoMax(4); dd.setAmmo(4);
        dd.setBuildCost(8);

        unitsData->addData(sd);
        unitsData->addData(dd);
    }

    // --- Vehicle 3: Alien Plane ---
    {
        cStaticUnitData sd;
        sd.ID = sID(0, 3);
        sd.setDefaultName(std::string("Alien Plane"));
        sd.setDefaultDescription(std::string("Alien air unit."));
        sd.canAttack = 1;
        sd.surfacePosition = eSurfacePosition::Above;
        sd.isAlien = true;
        sd.factorAir = 1.0f;
        sd.muzzleType = eMuzzleType::Rocket;

        cDynamicUnitData dd;
        dd.setId(sID(0, 3));
        dd.setHitpointsMax(12); dd.setHitpoints(12);
        dd.setSpeedMax(24); dd.setSpeed(24);
        dd.setScan(8); dd.setRange(4);
        dd.setArmor(2); dd.setDamage(10);
        dd.setShotsMax(1); dd.setShots(1);
        dd.setAmmoMax(6); dd.setAmmo(6);
        dd.setBuildCost(10);

        unitsData->addData(sd);
        unitsData->addData(dd);
    }

    // --- Vehicle 4: Alien Ship ---
    {
        cStaticUnitData sd;
        sd.ID = sID(0, 4);
        sd.setDefaultName(std::string("Alien Ship"));
        sd.setDefaultDescription(std::string("Alien naval unit."));
        sd.canAttack = 2;
        sd.surfacePosition = eSurfacePosition::AboveSea;
        sd.isAlien = true;
        sd.factorSea = 1.0f;
        sd.muzzleType = eMuzzleType::Med;

        cDynamicUnitData dd;
        dd.setId(sID(0, 4));
        dd.setHitpointsMax(20); dd.setHitpoints(20);
        dd.setSpeedMax(10); dd.setSpeed(10);
        dd.setScan(6); dd.setRange(4);
        dd.setArmor(6); dd.setDamage(12);
        dd.setShotsMax(1); dd.setShots(1);
        dd.setAmmoMax(4); dd.setAmmo(4);
        dd.setBuildCost(14);

        unitsData->addData(sd);
        unitsData->addData(dd);
    }

    // --- Vehicle 5: Alien Tank ---
    {
        cStaticUnitData sd;
        sd.ID = sID(0, 5);
        sd.setDefaultName(std::string("Alien Tank"));
        sd.setDefaultDescription(std::string("Alien armored unit."));
        sd.canAttack = 5;
        sd.surfacePosition = eSurfacePosition::Ground;
        sd.isAlien = true;
        sd.factorGround = 1.0f;
        sd.muzzleType = eMuzzleType::Big;

        cDynamicUnitData dd;
        dd.setId(sID(0, 5));
        dd.setHitpointsMax(28); dd.setHitpoints(28);
        dd.setSpeedMax(10); dd.setSpeed(10);
        dd.setScan(6); dd.setRange(5);
        dd.setArmor(10); dd.setDamage(16);
        dd.setShotsMax(1); dd.setShots(1);
        dd.setAmmoMax(6); dd.setAmmo(6);
        dd.setBuildCost(16);

        unitsData->addData(sd);
        unitsData->addData(dd);
    }

    // --- Vehicle 6: Surveyor ---
    {
        cStaticUnitData sd;
        sd.ID = sID(0, 6);
        sd.setDefaultName(std::string("Surveyor"));
        sd.setDefaultDescription(std::string("Resource surveying vehicle."));
        sd.surfacePosition = eSurfacePosition::Ground;
        sd.vehicleData.canSurvey = true;

        cDynamicUnitData dd;
        dd.setId(sID(0, 6));
        dd.setHitpointsMax(12); dd.setHitpoints(12);
        dd.setSpeedMax(18); dd.setSpeed(18);
        dd.setScan(5); dd.setRange(0);
        dd.setArmor(2); dd.setDamage(0);
        dd.setShotsMax(0); dd.setShots(0);
        dd.setAmmoMax(0); dd.setAmmo(0);
        dd.setBuildCost(4);

        unitsData->addData(sd);
        unitsData->addData(dd);
    }

    // --- Vehicle 7: Engineer ---
    {
        cStaticUnitData sd;
        sd.ID = sID(0, 7);
        sd.setDefaultName(std::string("Engineer"));
        sd.setDefaultDescription(std::string("Road and bridge builder."));
        sd.surfacePosition = eSurfacePosition::Ground;
        sd.vehicleData.canBuildPath = true;
        sd.vehicleData.canClearArea = true;

        cDynamicUnitData dd;
        dd.setId(sID(0, 7));
        dd.setHitpointsMax(16); dd.setHitpoints(16);
        dd.setSpeedMax(12); dd.setSpeed(12);
        dd.setScan(4); dd.setRange(0);
        dd.setArmor(4); dd.setDamage(0);
        dd.setShotsMax(0); dd.setShots(0);
        dd.setAmmoMax(0); dd.setAmmo(0);
        dd.setBuildCost(8);

        unitsData->addData(sd);
        unitsData->addData(dd);
    }

    // --- Building 0: Small Generator ---
    {
        cStaticUnitData sd;
        sd.ID = sID(1, 0);
        sd.setDefaultName(std::string("Small Generator"));
        sd.setDefaultDescription(std::string("Produces energy."));
        sd.surfacePosition = eSurfacePosition::Ground;
        sd.produceEnergy = 2;
        sd.buildingData.connectsToBase = true;

        cDynamicUnitData dd;
        dd.setId(sID(1, 0));
        dd.setHitpointsMax(24); dd.setHitpoints(24);
        dd.setSpeedMax(0); dd.setSpeed(0);
        dd.setScan(3); dd.setRange(0);
        dd.setArmor(6); dd.setDamage(0);
        dd.setShotsMax(0); dd.setShots(0);
        dd.setAmmoMax(0); dd.setAmmo(0);
        dd.setBuildCost(4);

        unitsData->addData(sd);
        unitsData->addData(dd);
    }

    // --- Building 1: Mining Station ---
    {
        cStaticUnitData sd;
        sd.ID = sID(1, 1);
        sd.setDefaultName(std::string("Mining Station"));
        sd.setDefaultDescription(std::string("Mines metal, oil, gold."));
        sd.surfacePosition = eSurfacePosition::Ground;
        sd.needsEnergy = 1;
        sd.buildingData.isBig = true;
        sd.buildingData.canMineMaxRes = 12;
        sd.buildingData.canWork = true;
        sd.buildingData.connectsToBase = true;

        cDynamicUnitData dd;
        dd.setId(sID(1, 1));
        dd.setHitpointsMax(48); dd.setHitpoints(48);
        dd.setSpeedMax(0); dd.setSpeed(0);
        dd.setScan(3); dd.setRange(0);
        dd.setArmor(8); dd.setDamage(0);
        dd.setShotsMax(0); dd.setShots(0);
        dd.setAmmoMax(0); dd.setAmmo(0);
        dd.setBuildCost(12);

        unitsData->addData(sd);
        unitsData->addData(dd);
    }

    // --- Building 2: Alien Factory ---
    {
        cStaticUnitData sd;
        sd.ID = sID(1, 2);
        sd.setDefaultName(std::string("Alien Factory"));
        sd.setDefaultDescription(std::string("Alien production facility."));
        sd.surfacePosition = eSurfacePosition::Ground;
        sd.isAlien = true;
        sd.buildingData.isBig = true;

        cDynamicUnitData dd;
        dd.setId(sID(1, 2));
        dd.setHitpointsMax(400); dd.setHitpoints(400);
        dd.setSpeedMax(0); dd.setSpeed(0);
        dd.setScan(5); dd.setRange(0);
        dd.setArmor(30); dd.setDamage(0);
        dd.setShotsMax(0); dd.setShots(0);
        dd.setAmmoMax(0); dd.setAmmo(0);
        dd.setBuildCost(0);

        unitsData->addData(sd);
        unitsData->addData(dd);
    }

    // --- Building 3: Connector ---
    {
        cStaticUnitData sd;
        sd.ID = sID(1, 3);
        sd.setDefaultName(std::string("Connector"));
        sd.setDefaultDescription(std::string("Connects buildings to base."));
        sd.surfacePosition = eSurfacePosition::Ground;
        sd.buildingData.connectsToBase = true;

        cDynamicUnitData dd;
        dd.setId(sID(1, 3));
        dd.setHitpointsMax(4); dd.setHitpoints(4);
        dd.setSpeedMax(0); dd.setSpeed(0);
        dd.setScan(1); dd.setRange(0);
        dd.setArmor(1); dd.setDamage(0);
        dd.setShotsMax(0); dd.setShots(0);
        dd.setAmmoMax(0); dd.setAmmo(0);
        dd.setBuildCost(1);

        unitsData->addData(sd);
        unitsData->addData(dd);
    }

    // Set special building IDs
    sSpecialBuildingsId bids;
    bids.alienFactory = 2;   // sID(1,2)
    bids.connector = 3;      // sID(1,3)
    bids.mine = 1;           // sID(1,1)
    bids.smallGenerator = 0; // sID(1,0)
    bids.landMine = 0;
    bids.seaMine = 0;
    bids.smallBeton = 0;
    unitsData->setSpecialBuildingIDs(bids);

    // initializeIDData scans for canBuild=="BigBuilding" etc.
    // Our constructor uses "big,small" which won't match, so set special vehicles manually
    // initializeIDData will set surveyor=6 (canSurvey=true)
    unitsData->initializeIDData();

    return unitsData;
}

// ========== SETUP TEST GAME ==========

Dictionary GameSetup::setup_test_game(cModel& model) {
    Array names;
    names.push_back(String("Player 1"));
    names.push_back(String("Player 2"));

    Array colors;
    colors.push_back(Color(0.0f, 0.0f, 1.0f));  // Blue
    colors.push_back(Color(1.0f, 0.0f, 0.0f));  // Red

    return setup_custom_game(model, names, colors, 64, 150);
}

// ========== SETUP CUSTOM GAME ==========

Dictionary GameSetup::setup_custom_game(
    cModel& model,
    Array player_names,
    Array player_colors,
    int map_size,
    int start_credits
) {
    Dictionary result;

    try {
        UtilityFunctions::print("[MaXtreme] ====================================");
        UtilityFunctions::print("[MaXtreme] Starting new game initialization...");
        UtilityFunctions::print("[MaXtreme] ====================================");

        // Validate map size (must be power of 2, >= 16)
        if (map_size < 16 || (map_size & (map_size - 1)) != 0) {
            UtilityFunctions::push_error("[MaXtreme] Invalid map size: ", map_size, ". Must be power of 2 >= 16");
            result["success"] = false;
            result["error"] = String("Invalid map size");
            return result;
        }

        int playerCount = std::min(static_cast<int>(player_names.size()),
                                   static_cast<int>(player_colors.size()));
        if (playerCount < 1 || playerCount > 8) {
            UtilityFunctions::push_error("[MaXtreme] Invalid player count: ", playerCount);
            result["success"] = false;
            result["error"] = String("Player count must be 1-8");
            return result;
        }

        // 1. Create and set unit data
        UtilityFunctions::print("[MaXtreme] Step 1/5: Loading unit definitions...");
        auto unitsData = create_test_units_data();
        model.setUnitsData(unitsData);
        int unitTypeCount = static_cast<int>(unitsData->getStaticUnitsData().size());
        UtilityFunctions::print("[MaXtreme]   -> ", unitTypeCount, " unit types defined (8 vehicles, 4 buildings)");

        // 2. Create game settings
        UtilityFunctions::print("[MaXtreme] Step 2/5: Configuring game settings...");
        cGameSettings settings;
        settings.startCredits = start_credits;
        settings.bridgeheadType = eGameSettingsBridgeheadType::Mobile;
        settings.alienEnabled = false;
        settings.clansEnabled = false;
        settings.gameType = eGameSettingsGameType::Simultaneous;
        settings.victoryConditionType = eGameSettingsVictoryCondition::Death;
        settings.metalAmount = eGameSettingsResourceAmount::Normal;
        settings.oilAmount = eGameSettingsResourceAmount::Normal;
        settings.goldAmount = eGameSettingsResourceAmount::Normal;
        settings.resourceDensity = eGameSettingsResourceDensity::Normal;
        model.setGameSettings(settings);
        UtilityFunctions::print("[MaXtreme]   -> Simultaneous turns, ", start_credits, " credits, no aliens");

        // 3. Create and load map
        UtilityFunctions::print("[MaXtreme] Step 3/5: Creating ", map_size, "x", map_size, " map...");
        auto staticMap = create_and_load_flat_map(map_size);
        if (!staticMap) {
            UtilityFunctions::push_error("[MaXtreme] Failed to create map!");
            result["success"] = false;
            result["error"] = String("Map creation failed");
            return result;
        }
        model.setMap(staticMap);
        UtilityFunctions::print("[MaXtreme]   -> Map set on model, size: ",
            model.getMap()->getSize().x(), "x", model.getMap()->getSize().y());

        // 4. Create players
        UtilityFunctions::print("[MaXtreme] Step 4/5: Creating ", playerCount, " players...");
        std::vector<cPlayerBasicData> players;
        for (int i = 0; i < playerCount; i++) {
            String name = player_names[i];
            Color color = player_colors[i];

            sPlayerSettings ps;
            ps.name = name.utf8().get_data();
            ps.color = cRgbColor(
                static_cast<unsigned char>(color.r * 255),
                static_cast<unsigned char>(color.g * 255),
                static_cast<unsigned char>(color.b * 255)
            );

            cPlayerBasicData pbd(ps, i, false);
            pbd.setReady(true);
            players.push_back(pbd);
            UtilityFunctions::print("[MaXtreme]   -> Player ", i, ": \"",
                String(ps.name.c_str()), "\" (RGB: ",
                static_cast<int>(color.r * 255), ",",
                static_cast<int>(color.g * 255), ",",
                static_cast<int>(color.b * 255), ")");
        }
        model.setPlayerList(players);

        // 5. Place starting units for each player
        UtilityFunctions::print("[MaXtreme] Step 5/5: Deploying starting forces...");
        int totalUnits = 0;
        for (int i = 0; i < playerCount; i++) {
            auto* player = model.getPlayer(i);
            if (!player) {
                UtilityFunctions::push_warning("[MaXtreme] Could not find player ", i);
                continue;
            }

            player->setCredits(start_credits);

            // Spread players evenly across the map
            int landX = (map_size / (playerCount + 1)) * (i + 1);
            int landY = map_size / 2;
            player->setLandingPos(cPosition(landX, landY));

            // Place starting units directly
            // Each player gets: 1 Constructor, 2 Tanks, 1 Surveyor
            auto& constructor = model.addVehicle(cPosition(landX, landY), sID(0, 0), player);
            totalUnits++;

            auto& tank1 = model.addVehicle(cPosition(landX + 1, landY), sID(0, 1), player);
            totalUnits++;

            auto& tank2 = model.addVehicle(cPosition(landX - 1, landY + 1), sID(0, 1), player);
            totalUnits++;

            auto& surveyor = model.addVehicle(cPosition(landX, landY - 1), sID(0, 6), player);
            totalUnits++;

            UtilityFunctions::print("[MaXtreme]   -> Player ", i, ": deployed at (",
                landX, ",", landY, ") with 4 units (Constructor, 2x Tank, Surveyor)");
        }

        // Initialize game ID
        model.initGameId();

        // Build result dictionary
        result["success"] = true;
        result["player_count"] = playerCount;
        result["units_total"] = totalUnits;
        result["units_per_player"] = 4;
        result["start_credits"] = start_credits;
        result["map_size"] = map_size;
        result["game_id"] = static_cast<int>(model.getGameId());
        result["unit_types"] = unitTypeCount;

        UtilityFunctions::print("[MaXtreme] ====================================");
        UtilityFunctions::print("[MaXtreme] GAME READY! ID: ", static_cast<int>(model.getGameId()));
        UtilityFunctions::print("[MaXtreme]   ", playerCount, " players, ",
            totalUnits, " units on ", map_size, "x", map_size, " map");
        UtilityFunctions::print("[MaXtreme] ====================================");

    } catch (const std::exception& e) {
        UtilityFunctions::push_error("[MaXtreme] Game setup FAILED: ", e.what());
        result["success"] = false;
        result["error"] = String(e.what());
    }

    return result;
}
