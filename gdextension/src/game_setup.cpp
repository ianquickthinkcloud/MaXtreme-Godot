#include "game_setup.h"

#include <godot_cpp/variant/utility_functions.hpp>

#include "game/data/model.h"
#include "game/data/map/map.h"
#include "game/data/gamesettings.h"
#include "game/data/player/player.h"
#include "game/data/player/playerbasicdata.h"
#include "game/data/player/playersettings.h"
#include "game/data/player/clans.h"
#include "game/data/units/unitdata.h"
#include "game/data/units/id.h"
#include "game/data/units/landingunit.h"
#include "game/data/units/vehicle.h"
#include "game/data/units/building.h"
#include "game/startup/initplayerdata.h"
#include "resources/loaddata.h"
#include "game/logic/upgradecalculator.h"
#include "utility/position.h"
#include "utility/color.h"
#include "utility/log.h"
#include "settings.h"

#include <cstdio>
#include <cstring>
#include <chrono>
#include <fstream>

using namespace godot;

// Static member
bool GameSetup::data_loaded = false;

// ========== BINDING ==========

void GameSetup::_bind_methods() {
    // GameSetup is used internally by GameEngine; no direct GDScript bindings needed
}

GameSetup::GameSetup() {}
GameSetup::~GameSetup() {}

// ========== DATA LOADING ==========

bool GameSetup::ensure_data_loaded() {
    if (data_loaded) return true;

    UtilityFunctions::print("[MaXtreme] Loading real M.A.X.R. game data from JSON files...");

    auto result = LoadData(false);
    if (result != eLoadingState::Finished) {
        UtilityFunctions::push_error("[MaXtreme] LoadData() FAILED! Check that data/ directory exists with vehicles/, buildings/, clans.json");
        return false;
    }

    data_loaded = true;

    auto vehicleCount = 0;
    auto buildingCount = 0;
    for (const auto& sd : UnitsDataGlobal.getStaticUnitsData()) {
        if (sd.ID.isAVehicle()) vehicleCount++;
        else if (sd.ID.isABuilding()) buildingCount++;
    }
    auto clanCount = static_cast<int>(UnitsDataGlobal.getNrOfClans());

    UtilityFunctions::print("[MaXtreme] Game data loaded successfully!");
    UtilityFunctions::print("[MaXtreme]   Vehicles:  ", vehicleCount);
    UtilityFunctions::print("[MaXtreme]   Buildings: ", buildingCount);
    UtilityFunctions::print("[MaXtreme]   Clans:     ", clanCount);
    UtilityFunctions::print("[MaXtreme]   Total unit types: ", vehicleCount + buildingCount);

    return true;
}

// ========== MAP LISTING ==========

Array GameSetup::get_available_maps() {
    Array maps;
    auto mapsPath = cSettings::getInstance().getMapsPath();

    if (!std::filesystem::exists(mapsPath)) {
        UtilityFunctions::push_warning("[MaXtreme] Maps directory not found: ", String(mapsPath.string().c_str()));
        return maps;
    }

    for (const auto& entry : std::filesystem::directory_iterator(mapsPath)) {
        if (entry.is_regular_file() && entry.path().extension() == ".wrl") {
            maps.push_back(String(entry.path().filename().string().c_str()));
        }
    }
    return maps;
}

// ========== CLAN LISTING ==========

Array GameSetup::get_available_clans() {
    Array clans;
    if (!data_loaded) {
        UtilityFunctions::push_warning("[MaXtreme] get_available_clans: data not loaded yet");
        return clans;
    }

    const auto& clanList = ClanDataGlobal.getClans();
    for (size_t i = 0; i < clanList.size(); i++) {
        const auto& clan = clanList[i];
        Dictionary clanInfo;
        clanInfo["index"] = static_cast<int>(i);
        clanInfo["name"] = String(clan.getDefaultName().c_str());
        clanInfo["description"] = String(clan.getDefaultDescription().c_str());
        clans.push_back(clanInfo);
    }
    return clans;
}

// ========== UNIT DATA INFO ==========

Dictionary GameSetup::get_unit_data_info() {
    Dictionary info;

    if (!data_loaded) {
        info["loaded"] = false;
        return info;
    }

    info["loaded"] = true;

    Array vehicles;
    Array buildings;
    for (const auto& sd : UnitsDataGlobal.getStaticUnitsData()) {
        Dictionary unit;
        unit["id_first"] = sd.ID.firstPart;
        unit["id_second"] = sd.ID.secondPart;
        unit["name"] = String(sd.getDefaultName().c_str());
        unit["description"] = String(sd.getDefaultDescription().c_str());

        if (sd.ID.isAVehicle()) {
            vehicles.push_back(unit);
        } else {
            buildings.push_back(unit);
        }
    }

    info["vehicles"] = vehicles;
    info["buildings"] = buildings;
    info["vehicle_count"] = vehicles.size();
    info["building_count"] = buildings.size();
    info["clan_count"] = static_cast<int>(UnitsDataGlobal.getNrOfClans());

    return info;
}

// ========== MAP LOADING ==========

std::shared_ptr<cStaticMap> GameSetup::load_map(const std::string& map_filename) {
    auto staticMap = std::make_shared<cStaticMap>();

    if (staticMap->loadMap(map_filename)) {
        UtilityFunctions::print("[MaXtreme]   Map loaded: ", String(map_filename.c_str()),
            " (", staticMap->getSize().x(), "x", staticMap->getSize().y(), ")");
        return staticMap;
    }

    UtilityFunctions::push_error("[MaXtreme] Failed to load map: ", String(map_filename.c_str()));
    return nullptr;
}

// ========== FALLBACK: WRL FILE CREATION ==========

bool GameSetup::write_wrl_file(const std::filesystem::path& path, int size) {
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

    int numTerrains = 1;
    file.write("WRL", 3);
    uint8_t padding[2] = {0, 0};
    file.write(reinterpret_cast<const char*>(padding), 2);
    uint16_t w = static_cast<uint16_t>(size);
    uint16_t h = static_cast<uint16_t>(size);
    file.write(reinterpret_cast<const char*>(&w), 2);
    file.write(reinterpret_cast<const char*>(&h), 2);
    std::vector<uint8_t> minimap(static_cast<size_t>(size) * size, 0);
    file.write(reinterpret_cast<const char*>(minimap.data()), minimap.size());
    std::vector<uint16_t> tiles(static_cast<size_t>(size) * size, 0);
    file.write(reinterpret_cast<const char*>(tiles.data()), tiles.size() * 2);
    uint16_t nt = static_cast<uint16_t>(numTerrains);
    file.write(reinterpret_cast<const char*>(&nt), 2);
    std::vector<uint8_t> terrainGfx(static_cast<size_t>(numTerrains) * 64 * 64, 32);
    file.write(reinterpret_cast<const char*>(terrainGfx.data()), terrainGfx.size());
    std::vector<uint8_t> palette(256 * 3);
    for (int i = 0; i < 256; i++) {
        palette[i * 3 + 0] = static_cast<uint8_t>(i);
        palette[i * 3 + 1] = static_cast<uint8_t>(i);
        palette[i * 3 + 2] = static_cast<uint8_t>(i);
    }
    file.write(reinterpret_cast<const char*>(palette.data()), palette.size());
    std::vector<uint8_t> terrainInfo(numTerrains, 0);
    file.write(reinterpret_cast<const char*>(terrainInfo.data()), terrainInfo.size());
    file.close();
    return true;
}

std::shared_ptr<cStaticMap> GameSetup::create_and_load_flat_map(int size) {
    auto mapsDir = cSettings::getInstance().getMapsPath();
    std::error_code ec;
    std::filesystem::create_directories(mapsDir, ec);

    auto mapFilePath = mapsDir / "fallback_flat.wrl";
    if (!write_wrl_file(mapFilePath, size)) {
        UtilityFunctions::push_error("[MaXtreme] Could not write fallback flat map");
        return nullptr;
    }

    auto staticMap = std::make_shared<cStaticMap>();
    if (staticMap->loadMap("fallback_flat.wrl")) {
        UtilityFunctions::print("[MaXtreme]   Fallback flat map loaded: ", size, "x", size);
        return staticMap;
    }

    UtilityFunctions::push_error("[MaXtreme] Failed to load fallback flat map");
    return nullptr;
}

// ========== SETUP TEST GAME ==========

Dictionary GameSetup::setup_test_game(cModel& model) {
    Array names;
    names.push_back(String("Player 1"));
    names.push_back(String("Player 2"));

    Array colors;
    colors.push_back(Color(0.0f, 0.0f, 1.0f));  // Blue
    colors.push_back(Color(1.0f, 0.0f, 0.0f));  // Red

    Array clans;
    clans.push_back(-1);  // No clan
    clans.push_back(-1);  // No clan

    // Use first available map, or empty string for fallback
    String map_name = "";
    Array available = get_available_maps();
    if (available.size() > 0) {
        map_name = available[0];
    }

    return setup_custom_game(model, map_name, names, colors, clans, 150);
}

// ========== SETUP CUSTOM GAME ==========

Dictionary GameSetup::setup_custom_game(
    cModel& model,
    String map_name,
    Array player_names,
    Array player_colors,
    Array player_clans,
    int start_credits
) {
    Dictionary result;

    try {
        UtilityFunctions::print("[MaXtreme] ====================================");
        UtilityFunctions::print("[MaXtreme] Starting new game initialization...");
        UtilityFunctions::print("[MaXtreme] ====================================");

        int playerCount = std::min(static_cast<int>(player_names.size()),
                                   static_cast<int>(player_colors.size()));
        if (playerCount < 1 || playerCount > 8) {
            UtilityFunctions::push_error("[MaXtreme] Invalid player count: ", playerCount);
            result["success"] = false;
            result["error"] = String("Player count must be 1-8");
            return result;
        }

        // 1. Load real game data from JSON
        UtilityFunctions::print("[MaXtreme] Step 1/5: Loading unit definitions from JSON...");
        if (!ensure_data_loaded()) {
            result["success"] = false;
            result["error"] = String("Failed to load game data from JSON files");
            return result;
        }

        // Set UnitsDataGlobal on the model via shared_ptr
        // The model needs its own copy of the units data
        auto unitsData = std::make_shared<cUnitsData>(UnitsDataGlobal);
        model.setUnitsData(unitsData);

        int vehicleCount = 0;
        int buildingCount = 0;
        for (const auto& sd : unitsData->getStaticUnitsData()) {
            if (sd.ID.isAVehicle()) vehicleCount++;
            else buildingCount++;
        }
        UtilityFunctions::print("[MaXtreme]   -> ", vehicleCount + buildingCount,
            " unit types loaded (", vehicleCount, " vehicles, ", buildingCount, " buildings)");

        // 2. Create game settings
        UtilityFunctions::print("[MaXtreme] Step 2/5: Configuring game settings...");
        cGameSettings settings;
        settings.startCredits = start_credits;
        settings.bridgeheadType = eGameSettingsBridgeheadType::Mobile;
        settings.alienEnabled = false;
        settings.clansEnabled = (!ClanDataGlobal.getClans().empty());
        settings.gameType = eGameSettingsGameType::Simultaneous;
        settings.victoryConditionType = eGameSettingsVictoryCondition::Death;
        settings.metalAmount = eGameSettingsResourceAmount::Normal;
        settings.oilAmount = eGameSettingsResourceAmount::Normal;
        settings.goldAmount = eGameSettingsResourceAmount::Normal;
        settings.resourceDensity = eGameSettingsResourceDensity::Normal;
        model.setGameSettings(settings);
        UtilityFunctions::print("[MaXtreme]   -> Simultaneous turns, ", start_credits,
            " credits, clans ", settings.clansEnabled ? "enabled" : "disabled");

        // 3. Load map
        UtilityFunctions::print("[MaXtreme] Step 3/5: Loading map...");
        std::shared_ptr<cStaticMap> staticMap;

        std::string mapFile = map_name.utf8().get_data();
        if (!mapFile.empty()) {
            staticMap = load_map(mapFile);
        }

        // If no map specified or load failed, try first available map
        if (!staticMap) {
            Array available = get_available_maps();
            for (int i = 0; i < available.size() && !staticMap; i++) {
                std::string fn = String(available[i]).utf8().get_data();
                staticMap = load_map(fn);
            }
        }

        // Last resort: generate a flat map
        if (!staticMap) {
            UtilityFunctions::push_warning("[MaXtreme] No real maps available, creating fallback 64x64 flat map");
            staticMap = create_and_load_flat_map(64);
        }

        if (!staticMap) {
            UtilityFunctions::push_error("[MaXtreme] Failed to load any map!");
            result["success"] = false;
            result["error"] = String("Map loading failed");
            return result;
        }
        model.setMap(staticMap);
        int mapW = model.getMap()->getSize().x();
        int mapH = model.getMap()->getSize().y();
        UtilityFunctions::print("[MaXtreme]   -> Map set on model, size: ", mapW, "x", mapH);

        // 4. Create players
        UtilityFunctions::print("[MaXtreme] Step 4/5: Creating ", playerCount, " players...");
        std::vector<cPlayerBasicData> players;
        for (int i = 0; i < playerCount; i++) {
            String name = player_names[i];
            Color color = player_colors[i];
            int clanIdx = (i < player_clans.size()) ? static_cast<int>(player_clans[i]) : -1;

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

            String clanName = (clanIdx >= 0 && clanIdx < static_cast<int>(ClanDataGlobal.getClans().size()))
                ? String(ClanDataGlobal.getClans()[clanIdx].getDefaultName().c_str())
                : String("None");
            UtilityFunctions::print("[MaXtreme]   -> Player ", i, ": \"",
                String(ps.name.c_str()), "\" clan=", clanName);
        }
        model.setPlayerList(players);

        // Apply clans to players (must be done after setPlayerList)
        for (int i = 0; i < playerCount; i++) {
            int clanIdx = (i < player_clans.size()) ? static_cast<int>(player_clans[i]) : -1;
            if (clanIdx >= 0 && clanIdx < static_cast<int>(ClanDataGlobal.getClans().size())) {
                auto* player = model.getPlayer(i);
                if (player) {
                    player->setClan(clanIdx, *unitsData);
                }
            }
        }

        // 5. Place starting units for each player
        UtilityFunctions::print("[MaXtreme] Step 5/5: Deploying starting forces...");

        // Find Constructor and Surveyor IDs from loaded data
        sID constructorId = unitsData->getConstructorID();
        sID surveyorId = unitsData->getSurveyorID();

        // Find the first combat vehicle (a tank-like unit with canAttack > 0 and ground movement)
        sID tankId;
        for (const auto& sd : unitsData->getStaticUnitsData()) {
            if (sd.ID.isAVehicle() && sd.canAttack > 0 &&
                sd.factorGround > 0 && !sd.isAlien &&
                sd.surfacePosition == eSurfacePosition::Ground) {
                tankId = sd.ID;
                break;
            }
        }

        if (!unitsData->isValidId(constructorId)) {
            UtilityFunctions::push_warning("[MaXtreme] Constructor ID not valid, using sID(0,0)");
            constructorId = sID(0, 0);
        }
        if (!unitsData->isValidId(surveyorId)) {
            UtilityFunctions::push_warning("[MaXtreme] Surveyor ID not valid, using sID(0,1)");
            surveyorId = sID(0, 1);
        }

        UtilityFunctions::print("[MaXtreme]   Constructor ID: ", constructorId.firstPart, ".", constructorId.secondPart,
            " (", String(unitsData->getStaticUnitData(constructorId).getDefaultName().c_str()), ")");
        UtilityFunctions::print("[MaXtreme]   Surveyor ID: ", surveyorId.firstPart, ".", surveyorId.secondPart,
            " (", String(unitsData->getStaticUnitData(surveyorId).getDefaultName().c_str()), ")");
        if (unitsData->isValidId(tankId)) {
            UtilityFunctions::print("[MaXtreme]   Tank ID: ", tankId.firstPart, ".", tankId.secondPart,
                " (", String(unitsData->getStaticUnitData(tankId).getDefaultName().c_str()), ")");
        }

        int totalUnits = 0;
        for (int i = 0; i < playerCount; i++) {
            auto* player = model.getPlayer(i);
            if (!player) {
                UtilityFunctions::push_warning("[MaXtreme] Could not find player ", i);
                continue;
            }

            player->setCredits(start_credits);

            // Spread players evenly across the map with some margin
            int margin = std::max(4, mapW / 8);
            int landX = margin + ((mapW - 2 * margin) / (playerCount + 1)) * (i + 1);
            int landY = mapH / 2;

            // Clamp to valid map positions
            landX = std::clamp(landX, 2, mapW - 3);
            landY = std::clamp(landY, 2, mapH - 3);

            player->setLandingPos(cPosition(landX, landY));

            // Place starting units: Constructor, 2x Tank (if available), Surveyor
            model.addVehicle(cPosition(landX, landY), constructorId, player);
            totalUnits++;

            if (unitsData->isValidId(tankId)) {
                model.addVehicle(cPosition(landX + 1, landY), tankId, player);
                totalUnits++;

                model.addVehicle(cPosition(landX - 1, landY + 1), tankId, player);
                totalUnits++;
            }

            model.addVehicle(cPosition(landX, landY - 1), surveyorId, player);
            totalUnits++;

            int unitsThisPlayer = unitsData->isValidId(tankId) ? 4 : 2;
            UtilityFunctions::print("[MaXtreme]   -> Player ", i, ": deployed at (",
                landX, ",", landY, ") with ", unitsThisPlayer, " units");
        }

        // Seed the random generator
        auto now = std::chrono::high_resolution_clock::now().time_since_epoch();
        uint64_t seed = static_cast<uint64_t>(std::chrono::duration_cast<std::chrono::nanoseconds>(now).count());
        model.randomGenerator.seed(seed);
        model.initGameId();

        // Build result dictionary
        result["success"] = true;
        result["player_count"] = playerCount;
        result["units_total"] = totalUnits;
        result["start_credits"] = start_credits;
        result["map_width"] = mapW;
        result["map_height"] = mapH;
        result["map_name"] = String(staticMap->getFilename().string().c_str());
        result["game_id"] = static_cast<int>(model.getGameId());
        result["vehicle_types"] = vehicleCount;
        result["building_types"] = buildingCount;
        result["clan_count"] = static_cast<int>(UnitsDataGlobal.getNrOfClans());

        UtilityFunctions::print("[MaXtreme] ====================================");
        UtilityFunctions::print("[MaXtreme] GAME READY! ID: ", static_cast<int>(model.getGameId()));
        UtilityFunctions::print("[MaXtreme]   ", playerCount, " players, ",
            totalUnits, " units on ", mapW, "x", mapH, " map");
        UtilityFunctions::print("[MaXtreme]   ", vehicleCount, " vehicle types, ",
            buildingCount, " building types, ",
            static_cast<int>(UnitsDataGlobal.getNrOfClans()), " clans");
        UtilityFunctions::print("[MaXtreme] ====================================");

    } catch (const std::exception& e) {
        UtilityFunctions::push_error("[MaXtreme] Game setup FAILED: ", e.what());
        result["success"] = false;
        result["error"] = String(e.what());
    }

    return result;
}

// ========== HELPER: parse enum strings ==========

static eGameSettingsGameType parse_game_type(const String& s) {
    if (s == "turns") return eGameSettingsGameType::Turns;
    if (s == "hotseat") return eGameSettingsGameType::HotSeat;
    return eGameSettingsGameType::Simultaneous;
}

static eGameSettingsVictoryCondition parse_victory_type(const String& s) {
    if (s == "turns") return eGameSettingsVictoryCondition::Turns;
    if (s == "points") return eGameSettingsVictoryCondition::Points;
    return eGameSettingsVictoryCondition::Death;
}

static eGameSettingsResourceAmount parse_resource_amount(const String& s) {
    if (s == "limited") return eGameSettingsResourceAmount::Limited;
    if (s == "high") return eGameSettingsResourceAmount::High;
    if (s == "toomuch") return eGameSettingsResourceAmount::TooMuch;
    return eGameSettingsResourceAmount::Normal;
}

static eGameSettingsResourceDensity parse_resource_density(const String& s) {
    if (s == "sparse") return eGameSettingsResourceDensity::Sparse;
    if (s == "dense") return eGameSettingsResourceDensity::Dense;
    if (s == "toomuch") return eGameSettingsResourceDensity::TooMuch;
    return eGameSettingsResourceDensity::Normal;
}

static eGameSettingsBridgeheadType parse_bridgehead_type(const String& s) {
    if (s == "mobile") return eGameSettingsBridgeheadType::Mobile;
    return eGameSettingsBridgeheadType::Definite;
}

// ========== SETUP CUSTOM GAME (Extended with full settings) ==========

Dictionary GameSetup::setup_custom_game_ex(
    cModel& model,
    Dictionary game_settings
) {
    // Extract player/map parameters from the settings dictionary
    String map_name = game_settings.get("map_name", String(""));
    Array player_names = game_settings.get("player_names", Array());
    Array player_colors = game_settings.get("player_colors", Array());
    Array player_clans = game_settings.get("player_clans", Array());
    int start_credits = game_settings.get("start_credits", 150);

    Dictionary result;

    try {
        UtilityFunctions::print("[MaXtreme] ====================================");
        UtilityFunctions::print("[MaXtreme] Starting new game (extended settings)...");
        UtilityFunctions::print("[MaXtreme] ====================================");

        int playerCount = std::min(static_cast<int>(player_names.size()),
                                   static_cast<int>(player_colors.size()));
        if (playerCount < 1 || playerCount > 8) {
            UtilityFunctions::push_error("[MaXtreme] Invalid player count: ", playerCount);
            result["success"] = false;
            result["error"] = String("Player count must be 1-8");
            return result;
        }

        // 1. Load real game data from JSON
        UtilityFunctions::print("[MaXtreme] Step 1/5: Loading unit definitions from JSON...");
        if (!ensure_data_loaded()) {
            result["success"] = false;
            result["error"] = String("Failed to load game data from JSON files");
            return result;
        }

        auto unitsData = std::make_shared<cUnitsData>(UnitsDataGlobal);
        model.setUnitsData(unitsData);

        int vehicleCount = 0;
        int buildingCount = 0;
        for (const auto& sd : unitsData->getStaticUnitsData()) {
            if (sd.ID.isAVehicle()) vehicleCount++;
            else buildingCount++;
        }
        UtilityFunctions::print("[MaXtreme]   -> ", vehicleCount + buildingCount,
            " unit types loaded (", vehicleCount, " vehicles, ", buildingCount, " buildings)");

        // 2. Create game settings from the Dictionary
        UtilityFunctions::print("[MaXtreme] Step 2/5: Configuring game settings...");
        cGameSettings settings;
        settings.startCredits = start_credits;

        // Game type
        String game_type_str = game_settings.get("game_type", String("simultaneous"));
        settings.gameType = parse_game_type(game_type_str);

        // Victory condition
        String victory_str = game_settings.get("victory_type", String("death"));
        settings.victoryConditionType = parse_victory_type(victory_str);
        settings.victoryTurns = game_settings.get("victory_turns", 200);
        settings.victoryPoints = game_settings.get("victory_points", 400);

        // Resources
        String metal_str = game_settings.get("metal_amount", String("normal"));
        String oil_str = game_settings.get("oil_amount", String("normal"));
        String gold_str = game_settings.get("gold_amount", String("normal"));
        String density_str = game_settings.get("resource_density", String("normal"));
        settings.metalAmount = parse_resource_amount(metal_str);
        settings.oilAmount = parse_resource_amount(oil_str);
        settings.goldAmount = parse_resource_amount(gold_str);
        settings.resourceDensity = parse_resource_density(density_str);

        // Bridgehead
        String bridgehead_str = game_settings.get("bridgehead_type", String("mobile"));
        settings.bridgeheadType = parse_bridgehead_type(bridgehead_str);

        // Toggles
        settings.alienEnabled = game_settings.get("alien_enabled", false);
        settings.clansEnabled = game_settings.get("clans_enabled", !ClanDataGlobal.getClans().empty());

        // Turn time limits
        settings.turnLimitActive = game_settings.get("turn_limit_active", false);
        int turnLimitSec = game_settings.get("turn_limit_seconds", 0);
        if (turnLimitSec > 0) {
            settings.turnLimit = std::chrono::seconds(turnLimitSec);
        }

        settings.turnEndDeadlineActive = game_settings.get("turn_deadline_active", false);
        int deadlineSec = game_settings.get("turn_deadline_seconds", 0);
        if (deadlineSec > 0) {
            settings.turnEndDeadline = std::chrono::seconds(deadlineSec);
        }

        model.setGameSettings(settings);

        // Log game type info
        const char* gameTypeName =
            settings.gameType == eGameSettingsGameType::HotSeat ? "Hot Seat" :
            settings.gameType == eGameSettingsGameType::Turns ? "Turn-based" :
            "Simultaneous";
        const char* victoryName =
            settings.victoryConditionType == eGameSettingsVictoryCondition::Turns ? "Turn Limit" :
            settings.victoryConditionType == eGameSettingsVictoryCondition::Points ? "Points" :
            "Elimination";
        UtilityFunctions::print("[MaXtreme]   -> ", gameTypeName, " mode, ", victoryName,
            " victory, ", start_credits, " credits");

        // 3. Load map
        UtilityFunctions::print("[MaXtreme] Step 3/5: Loading map...");
        std::shared_ptr<cStaticMap> staticMap;
        std::string mapFile = map_name.utf8().get_data();
        if (!mapFile.empty()) {
            staticMap = load_map(mapFile);
        }
        if (!staticMap) {
            Array available = get_available_maps();
            for (int i = 0; i < available.size() && !staticMap; i++) {
                std::string fn = String(available[i]).utf8().get_data();
                staticMap = load_map(fn);
            }
        }
        if (!staticMap) {
            UtilityFunctions::push_warning("[MaXtreme] No real maps available, creating fallback 64x64 flat map");
            staticMap = create_and_load_flat_map(64);
        }
        if (!staticMap) {
            result["success"] = false;
            result["error"] = String("Map loading failed");
            return result;
        }
        model.setMap(staticMap);
        int mapW = model.getMap()->getSize().x();
        int mapH = model.getMap()->getSize().y();

        // 4. Create players
        UtilityFunctions::print("[MaXtreme] Step 4/5: Creating ", playerCount, " players...");
        std::vector<cPlayerBasicData> players;
        for (int i = 0; i < playerCount; i++) {
            String name = player_names[i];
            Color color = player_colors[i];
            int clanIdx = (i < player_clans.size()) ? static_cast<int>(player_clans[i]) : -1;

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
        }
        model.setPlayerList(players);

        // Apply clans
        for (int i = 0; i < playerCount; i++) {
            int clanIdx = (i < player_clans.size()) ? static_cast<int>(player_clans[i]) : -1;
            if (clanIdx >= 0 && clanIdx < static_cast<int>(ClanDataGlobal.getClans().size())) {
                auto* player = model.getPlayer(i);
                if (player) {
                    player->setClan(clanIdx, *unitsData);
                }
            }
        }

        // 5. Place starting units
        UtilityFunctions::print("[MaXtreme] Step 5/5: Deploying starting forces...");

        // Check if the caller provided per-player landing units and positions
        bool hasCustomUnits = game_settings.has("player_landing_units");
        bool hasCustomPositions = game_settings.has("player_landing_positions");
        Array customUnitsPerPlayer = game_settings.get("player_landing_units", Array());
        Array customPositions = game_settings.get("player_landing_positions", Array());

        int totalUnits = 0;
        for (int i = 0; i < playerCount; i++) {
            auto* player = model.getPlayer(i);
            if (!player) continue;

            // --- Determine landing position ---
            int landX, landY;
            if (hasCustomPositions && i < customPositions.size()) {
                Vector2i pos = customPositions[i];
                landX = std::clamp(static_cast<int>(pos.x), 2, mapW - 3);
                landY = std::clamp(static_cast<int>(pos.y), 2, mapH - 3);
            } else {
                // Fallback: evenly spaced positions
                int margin = std::max(4, mapW / 8);
                landX = margin + ((mapW - 2 * margin) / (playerCount + 1)) * (i + 1);
                landY = mapH / 2;
                landX = std::clamp(landX, 2, mapW - 3);
                landY = std::clamp(landY, 2, mapH - 3);
            }
            player->setLandingPos(cPosition(landX, landY));

            // --- Determine landing units ---
            if (hasCustomUnits && i < customUnitsPerPlayer.size()) {
                // Player-chosen units from the purchase screen
                Array playerUnits = customUnitsPerPlayer[i];
                int creditsSpent = 0;

                // Place units in a spiral around the landing position.
                // We use a simple spiral placement: center, then ring 1, ring 2, etc.
                // Build a list of offset positions sorted by distance.
                std::vector<cPosition> offsets;
                offsets.push_back(cPosition(0, 0));
                for (int r = 1; r <= 8; r++) {
                    for (int dx = -r; dx <= r; dx++) {
                        for (int dy = -r; dy <= r; dy++) {
                            if (abs(dx) == r || abs(dy) == r) {
                                offsets.push_back(cPosition(dx, dy));
                            }
                        }
                    }
                }

                int placed = 0;
                size_t nextOffset = 0;
                for (int u = 0; u < playerUnits.size(); u++) {
                    Dictionary unitDict = playerUnits[u];
                    int idFirst = unitDict.get("id_first", 0);
                    int idSecond = unitDict.get("id_second", 0);
                    int cargo = unitDict.get("cargo", 0);
                    int cost = unitDict.get("cost", 0);
                    sID unitId(idFirst, idSecond);

                    if (!unitsData->isValidId(unitId)) continue;

                    // Find next free offset position
                    while (nextOffset < offsets.size()) {
                        int px = landX + offsets[nextOffset].x();
                        int py = landY + offsets[nextOffset].y();
                        nextOffset++;
                        if (px < 1 || px >= mapW - 1 || py < 1 || py >= mapH - 1) continue;
                        cPosition tryPos(px, py);
                        try {
                            auto& vehicle = model.addVehicle(tryPos, unitId, player);
                            if (cargo > 0) {
                                const auto& staticData = unitsData->getStaticUnitData(unitId);
                                vehicle.setStoredResources(std::min(cargo, staticData.storageResMax));
                            }
                            totalUnits++;
                            creditsSpent += cost;
                            placed++;
                            break;
                        } catch (...) {
                            // Position occupied or invalid, try next offset
                            continue;
                        }
                    }
                }

                // Remaining credits = start_credits - cost of purchased units
                int remainingCredits = std::max(0, start_credits - creditsSpent);
                player->setCredits(remainingCredits);
                UtilityFunctions::print("[MaXtreme]   -> Player ", i, ": deployed ", placed,
                    " custom units at (", landX, ",", landY, "), ",
                    remainingCredits, " credits remaining");
            } else {
                // Fallback: hardcoded starting units (legacy behavior)
                player->setCredits(start_credits);

                sID constructorId = unitsData->getConstructorID();
                sID surveyorId = unitsData->getSurveyorID();
                sID tankId;
                for (const auto& sd : unitsData->getStaticUnitsData()) {
                    if (sd.ID.isAVehicle() && sd.canAttack > 0 &&
                        sd.factorGround > 0 && !sd.isAlien &&
                        sd.surfacePosition == eSurfacePosition::Ground) {
                        tankId = sd.ID;
                        break;
                    }
                }
                if (!unitsData->isValidId(constructorId)) constructorId = sID(0, 0);
                if (!unitsData->isValidId(surveyorId)) surveyorId = sID(0, 1);

                model.addVehicle(cPosition(landX, landY), constructorId, player);
                totalUnits++;
                if (unitsData->isValidId(tankId)) {
                    model.addVehicle(cPosition(landX + 1, landY), tankId, player);
                    totalUnits++;
                    model.addVehicle(cPosition(landX - 1, landY + 1), tankId, player);
                    totalUnits++;
                }
                model.addVehicle(cPosition(landX, landY - 1), surveyorId, player);
                totalUnits++;

                UtilityFunctions::print("[MaXtreme]   -> Player ", i, ": deployed at (",
                    landX, ",", landY, ") with default units");
            }
        }

        // Seed RNG
        auto now = std::chrono::high_resolution_clock::now().time_since_epoch();
        uint64_t seed = static_cast<uint64_t>(std::chrono::duration_cast<std::chrono::nanoseconds>(now).count());
        model.randomGenerator.seed(seed);
        model.initGameId();

        // Build result
        result["success"] = true;
        result["player_count"] = playerCount;
        result["units_total"] = totalUnits;
        result["start_credits"] = start_credits;
        result["map_width"] = mapW;
        result["map_height"] = mapH;
        result["map_name"] = String(staticMap->getFilename().string().c_str());
        result["game_type"] = game_type_str;
        result["victory_type"] = victory_str;

        UtilityFunctions::print("[MaXtreme] ====================================");
        UtilityFunctions::print("[MaXtreme] GAME READY! ", gameTypeName, " mode");
        UtilityFunctions::print("[MaXtreme]   ", playerCount, " players, ",
            totalUnits, " units on ", mapW, "x", mapH, " map");
        UtilityFunctions::print("[MaXtreme] ====================================");

    } catch (const std::exception& e) {
        UtilityFunctions::push_error("[MaXtreme] Game setup FAILED: ", e.what());
        result["success"] = false;
        result["error"] = String(e.what());
    }

    return result;
}

// ========== PHASE 18: PRE-GAME SETUP DATA ==========

#include "game/startup/gamepreparation.h"

Array GameSetup::get_purchasable_vehicles(int clan) {
    Array vehicles;
    if (!ensure_data_loaded()) return vehicles;

    for (const auto& sd : UnitsDataGlobal.getStaticUnitsData()) {
        if (!sd.ID.isAVehicle()) continue;

        // Get clan-modified dynamic data (or base if clan == -1)
        const auto& dd = UnitsDataGlobal.getDynamicUnitData(sd.ID, clan);

        Dictionary unit;
        unit["id_first"] = sd.ID.firstPart;
        unit["id_second"] = sd.ID.secondPart;
        unit["name"] = String(sd.getDefaultName().c_str());
        unit["description"] = String(sd.getDefaultDescription().c_str());
        unit["cost"] = dd.getBuildCost();
        unit["hitpoints"] = dd.getHitpointsMax();
        unit["armor"] = dd.getArmor();
        unit["damage"] = dd.getDamage();
        unit["speed"] = dd.getSpeedMax();
        unit["scan"] = dd.getScan();
        unit["range"] = dd.getRange();
        unit["shots"] = dd.getShotsMax();
        unit["ammo"] = dd.getAmmoMax();
        unit["can_attack"] = static_cast<int>(sd.canAttack);
        unit["is_alien"] = sd.isAlien;
        unit["storage_res_max"] = static_cast<int>(sd.storageResMax);

        // Surface position as a string
        const char* surfStr = "ground";
        switch (sd.surfacePosition) {
            case eSurfacePosition::AboveSea: surfStr = "sea"; break;
            case eSurfacePosition::BeneathSea: surfStr = "sub"; break;
            case eSurfacePosition::Above: surfStr = "air"; break;
            default: surfStr = "ground"; break;
        }
        unit["surface"] = String(surfStr);

        // Capabilities
        unit["can_build"] = String(sd.canBuild.c_str());

        vehicles.push_back(unit);
    }

    return vehicles;
}

Array GameSetup::get_initial_landing_units(int clan, int start_credits, const String& bridgehead_type) {
    Array result;
    if (!ensure_data_loaded()) return result;

    bool isMobile = (bridgehead_type == "mobile");

    if (isMobile) {
        // Mobile bridgehead: no free units, player buys everything
        return result;
    }

    // Definite bridgehead: use the original computation
    cGameSettings tempSettings;
    tempSettings.startCredits = start_credits;
    tempSettings.bridgeheadType = eGameSettingsBridgeheadType::Definite;

    auto initialUnits = computeInitialLandingUnits(clan, tempSettings, UnitsDataGlobal);

    for (const auto& [unitId, cargo] : initialUnits) {
        Dictionary d;
        d["id_first"] = unitId.firstPart;
        d["id_second"] = unitId.secondPart;
        d["cargo"] = cargo;
        if (UnitsDataGlobal.isValidId(unitId)) {
            d["name"] = String(UnitsDataGlobal.getStaticUnitData(unitId).getDefaultName().c_str());
            const auto& dd = UnitsDataGlobal.getDynamicUnitData(unitId, clan);
            d["cost"] = dd.getBuildCost();
        } else {
            d["name"] = String("Unknown");
            d["cost"] = 0;
        }
        result.push_back(d);
    }

    return result;
}

Array GameSetup::get_clan_details() {
    Array clans;
    if (!ensure_data_loaded()) return clans;

    const auto& clanList = ClanDataGlobal.getClans();
    for (size_t i = 0; i < clanList.size(); i++) {
        const auto& clan = clanList[i];
        Dictionary clanInfo;
        clanInfo["index"] = static_cast<int>(i);
        clanInfo["name"] = String(clan.getDefaultName().c_str());
        clanInfo["description"] = String(clan.getDefaultDescription().c_str());

        // Collect stat modifications
        Array modifications;
        for (const auto& sd : UnitsDataGlobal.getStaticUnitsData()) {
            auto unitStatOpt = clan.getUnitStat(sd.ID);
            if (!unitStatOpt) continue;

            const auto& unitStat = *unitStatOpt;
            Dictionary mod;
            mod["unit_id_first"] = sd.ID.firstPart;
            mod["unit_id_second"] = sd.ID.secondPart;
            mod["unit_name"] = String(sd.getDefaultName().c_str());

            // Check each possible modification
            auto dmg = unitStat.getModificationValue(eClanModification::Damage);
            auto rng = unitStat.getModificationValue(eClanModification::Range);
            auto arm = unitStat.getModificationValue(eClanModification::Armor);
            auto hp = unitStat.getModificationValue(eClanModification::Hitpoints);
            auto scn = unitStat.getModificationValue(eClanModification::Scan);
            auto spd = unitStat.getModificationValue(eClanModification::Speed);
            auto bld = unitStat.getModificationValue(eClanModification::Built_Costs);

            Dictionary stats;
            if (dmg.has_value()) stats["damage"] = dmg.value();
            if (rng.has_value()) stats["range"] = rng.value();
            if (arm.has_value()) stats["armor"] = arm.value();
            if (hp.has_value()) stats["hitpoints"] = hp.value();
            if (scn.has_value()) stats["scan"] = scn.value();
            if (spd.has_value()) stats["speed"] = spd.value();
            if (bld.has_value()) stats["build_cost"] = bld.value();

            if (stats.size() > 0) {
                mod["modifications"] = stats;
                modifications.push_back(mod);
            }
        }

        clanInfo["modifications"] = modifications;
        clans.push_back(clanInfo);
    }

    return clans;
}

bool GameSetup::check_landing_position(const String& map_name, Vector2i pos) {
    if (!ensure_data_loaded()) return false;

    std::string mapFile = map_name.utf8().get_data();
    auto staticMap = load_map(mapFile);
    if (!staticMap) return false;

    int mapW = staticMap->getSize().x();
    int mapH = staticMap->getSize().y();

    // Basic bounds check with margin
    if (pos.x < 2 || pos.x >= mapW - 2 || pos.y < 2 || pos.y >= mapH - 2)
        return false;

    return true;
}

// --- Phase 21: Pre-game upgrade info ---

Array GameSetup::get_pregame_upgrade_info(int clan) {
    if (!ensure_data_loaded()) return Array();

    const auto& unitsData = UnitsDataGlobal;
    cResearch research;  // Default: all levels at 0

    Array result;
    const auto& allDynamic = unitsData.getDynamicUnitsData(clan);

    for (const auto& origData : allDynamic) {
        sID unitId = origData.getId();
        if (!unitsData.isValidId(unitId)) continue;

        const auto& staticData = unitsData.getStaticUnitData(unitId);

        // For pre-game, "current" data is the same as "original" (no upgrades yet)
        cUnitUpgrade upgrade;
        upgrade.init(origData, origData, staticData, research);

        // Check if this unit has any upgradeable stats
        bool hasUpgrades = false;
        for (int s = 0; s < 8; s++) {
            if (upgrade.upgrades[s].getType() != sUnitUpgrade::eUpgradeType::None &&
                upgrade.upgrades[s].getCurValue() > 0) {
                auto price = upgrade.upgrades[s].getNextPrice();
                if (price && *price > 0) {
                    hasUpgrades = true;
                    break;
                }
            }
        }
        if (!hasUpgrades) continue;

        Dictionary unitInfo;
        unitInfo["id_first"] = unitId.firstPart;
        unitInfo["id_second"] = unitId.secondPart;
        unitInfo["name"] = String(staticData.getDefaultName().c_str());
        unitInfo["build_cost"] = origData.getBuildCost();

        Array upgrades;
        const char* typeNames[] = {"damage", "shots", "range", "ammo", "armor", "hits", "scan", "speed"};
        for (int s = 0; s < 8; s++) {
            const auto& u = upgrade.upgrades[s];
            if (u.getType() == sUnitUpgrade::eUpgradeType::None) continue;
            if (u.getCurValue() <= 0) continue;

            Dictionary stat;
            stat["index"] = s;
            stat["type"] = String(typeNames[s]);
            stat["cur_value"] = u.getCurValue();
            stat["next_price"] = u.getNextPrice() ? static_cast<int>(*u.getNextPrice()) : -1;
            stat["purchased"] = 0;
            upgrades.push_back(stat);
        }

        unitInfo["upgrades"] = upgrades;
        result.push_back(unitInfo);
    }

    return result;
}
