/***************************************************************************
 *      Mechanized Assault and Exploration Reloaded Projectfile            *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   along with this program; if not, write to the                         *
 *   Free Software Foundation, Inc.,                                       *
 *   59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.             *
 ***************************************************************************/
///////////////////////////////////////////////////////////////////////////////
//
// Loads all relevant game data files (JSON only, no graphics/sound).
// Adapted from maxr-release-0.2.17 loaddata.cpp for GDExtension use.
//
///////////////////////////////////////////////////////////////////////////////

#include "loaddata.h"

#include "game/data/player/clans.h"
#include "game/data/units/building.h"
#include "game/data/units/vehicle.h"
#include "resources/buildinguidata.h"
#include "resources/vehicleuidata.h"
#include "settings.h"
#include "utility/log.h"
#include "utility/serialization/jsonarchive.h"

#include <algorithm>
#include <filesystem>
#include <fstream>
#include <iostream>

namespace
{
	//--------------------------------------------------------------------------
	struct sInitialDynamicUnitData
	{
		int ammoMax = 0;
		int shotsMax = 0;
		int range = 0;
		int damage = 0;
		int buildCost = 0;
		int speedMax = 0;
		int armor = 0;
		int hitpointsMax = 0;
		int scan = 0;

		template <typename Archive>
		void serialize (Archive& archive)
		{
			// clang-format off
			archive & NVP (ammoMax);
			archive & NVP (shotsMax);
			archive & NVP (range);
			archive & NVP (damage);
			archive & NVP (buildCost);
			archive & NVP (speedMax);
			archive & NVP (armor);
			archive & NVP (hitpointsMax);
			archive & NVP (scan);
			// clang-format on
		}
	};

	//--------------------------------------------------------------------------
	struct sInitialBuildingData
	{
		sID id;
		std::string defaultName;
		std::string description;
		sStaticCommonUnitData commonData;
		sInitialDynamicUnitData dynamicData;
		sStaticBuildingData staticBuildingData;
		sBuildingUIStaticData graphic; // consumed from JSON but not used

		template <typename Archive>
		void serialize (Archive& archive)
		{
			// clang-format off
			archive & NVP (id);
			archive & NVP (defaultName);
			archive & NVP (description);
			commonData.serialize (archive);
			dynamicData.serialize (archive);
			staticBuildingData.serialize (archive);
			archive & NVP (graphic);
			// clang-format on
		}
	};

	//--------------------------------------------------------------------------
	struct sInitialVehicleData
	{
		sID id;
		std::string defaultName;
		std::string description;
		sStaticCommonUnitData commonData;
		sInitialDynamicUnitData dynamicData;
		sStaticVehicleData staticVehicleData;
		sVehicleUIStaticData graphic; // consumed from JSON but not used

		template <typename Archive>
		void serialize (Archive& archive)
		{
			// clang-format off
			archive & NVP (id);
			archive & NVP (defaultName);
			archive & NVP (description);
			commonData.serialize (archive);
			dynamicData.serialize (archive);
			staticVehicleData.serialize (archive);
			archive & NVP (graphic);
			// clang-format on
		}
	};

	//--------------------------------------------------------------------------
	struct sUnitDirectory
	{
		int id = -1;
		std::filesystem::path path;
		int insertionIndex = ++currentIndex;
		static int currentIndex;

		template <typename Archive>
		void serialize (Archive& archive)
		{
			// clang-format off
			archive & NVP (id);
			archive & NVP (path);
			// clang-format on
		}
	};

	/*static*/ int sUnitDirectory::currentIndex = 0;

	//--------------------------------------------------------------------------
	void checkDuplicateId (std::vector<sUnitDirectory>& v)
	{
		std::sort (v.begin(), v.end(), [] (const auto& lhs, const auto& rhs) { return lhs.id < rhs.id; });
		auto sameId = [] (const auto& lhs, const auto& rhs) { return lhs.id == rhs.id; };
		auto it = std::adjacent_find (v.begin(), v.end(), sameId);
		while (it != v.end())
		{
			Log.warn ("duplicated id " + std::to_string (it->id) + ", skipping unit.");
			it = std::adjacent_find (it + 1, v.end(), sameId);
		}
		v.erase (std::unique (v.begin(), v.end(), sameId), v.end());
		std::sort (v.begin(), v.end(), [] (const auto& lhs, const auto& rhs) { return lhs.insertionIndex < rhs.insertionIndex; });
	}

	//--------------------------------------------------------------------------
	struct sBuildingsList
	{
		sSpecialBuildingsId special;
		std::vector<sUnitDirectory> buildings;

		template <typename Archive>
		void serialize (Archive& archive)
		{
			// clang-format off
			archive & NVP (special);
			archive & NVP (buildings);
			// clang-format on
		}
	};

	//--------------------------------------------------------------------------
	struct sVehiclesList
	{
		std::vector<sUnitDirectory> vehicles;

		template <typename Archive>
		void serialize (Archive& archive)
		{
			// clang-format off
			archive & NVP (vehicles);
			// clang-format on
		}
	};

} // namespace

//------------------------------------------------------------------------------
static void LoadUnitData (sInitialBuildingData& buildingData, const std::filesystem::path& directory)
{
	const auto path = directory / "data.json";
	if (!std::filesystem::exists (path)) return;

	std::ifstream file (path);
	nlohmann::json json;

	if (!(file >> json))
	{
		Log.warn ("Can't load " + path.string());
		return;
	}
	cJsonArchiveIn in (json);
	in >> buildingData;
}

//------------------------------------------------------------------------------
static void LoadUnitData (sInitialVehicleData& vehicleData, const std::filesystem::path& directory)
{
	auto path = directory / "data.json";
	if (!std::filesystem::exists (path)) return;

	std::ifstream file (path);
	nlohmann::json json;

	if (!(file >> json))
	{
		Log.warn ("Can't load " + path.string());
		return;
	}
	cJsonArchiveIn in (json);
	in >> vehicleData;
}

//------------------------------------------------------------------------------
static bool checkUniqueness (const sID& id)
{
	const auto& allStatic = UnitsDataGlobal.getStaticUnitsData();
	for (const auto& data : allStatic)
	{
		if (data.ID == id)
		{
			char szTmp[100];
			snprintf (szTmp, sizeof (szTmp), "unit with id %.2d %.2d already exists", id.firstPart, id.secondPart);
			Log.warn (szTmp);
			return false;
		}
	}
	return true;
}

//------------------------------------------------------------------------------
static cDynamicUnitData createDynamicUnitData (const sID& id, const sInitialDynamicUnitData& dynamic)
{
	cDynamicUnitData res;

	res.setId (id);
	res.setAmmoMax (dynamic.ammoMax);
	res.setShotsMax (dynamic.shotsMax);
	res.setRange (dynamic.range);
	res.setDamage (dynamic.damage);
	res.setBuildCost (dynamic.buildCost);
	res.setSpeedMax (dynamic.speedMax * 4);
	res.setArmor (dynamic.armor);
	res.setHitpointsMax (dynamic.hitpointsMax);
	res.setScan (dynamic.scan);
	return res;
}

//------------------------------------------------------------------------------
static cStaticUnitData createStaticUnitData (const sID& id, const sStaticCommonUnitData& commonData, std::string&& name, std::string&& desc)
{
	cStaticUnitData res;
	static_cast<sStaticCommonUnitData&> (res) = commonData;
	res.ID = id;
	res.setDefaultName (std::move (name));
	res.setDefaultDescription (std::move (desc));

	// TODO: make the code differ between attacking sea units and land units.
	// until this is done being able to attack sea units means being able to attack ground units.
	if (res.canAttack & eTerrainFlag::Sea) res.canAttack |= eTerrainFlag::Ground;

	return res;
}

//------------------------------------------------------------------------------
/**
 * Loads all Buildings (JSON data only, no graphics/sound)
 * @return 1 on success
 */
static int LoadBuildings()
{
	Log.info ("Loading Buildings");

	auto buildingsJsonPath = cSettings::getInstance().getBuildingsPath() / "buildings.json";
	if (!std::filesystem::exists (buildingsJsonPath))
	{
		Log.error ("buildings.json doesn't exist at: " + buildingsJsonPath.string());
		return 0;
	}

	std::ifstream file (buildingsJsonPath);
	nlohmann::json json;

	if (!(file >> json))
	{
		Log.error ("Can't load " + buildingsJsonPath.string());
		return 0;
	}
	sBuildingsList buildingsList;
	cJsonArchiveIn in (json);
	in >> buildingsList;

	checkDuplicateId (buildingsList.buildings);
	buildingsList.special.logMissing();
	UnitsDataGlobal.setSpecialBuildingIDs (buildingsList.special);

	for (const auto& p : buildingsList.buildings)
	{
		const auto sBuildingPath = cSettings::getInstance().getBuildingsPath() / p.path;

		sInitialBuildingData buildingData;
		LoadUnitData (buildingData, sBuildingPath);

		if (p.id != buildingData.id.secondPart)
		{
			Log.error ("ID " + std::to_string (p.id) + " isn't equal with ID from directory " + sBuildingPath.string());
			return 0;
		}
		else
		{
			Log.debug ("id " + std::to_string (p.id) + " verified for " + sBuildingPath.string());
		}
		if (!checkUniqueness (buildingData.id)) return 0;

		cStaticUnitData staticData = createStaticUnitData (buildingData.id, buildingData.commonData, std::move (buildingData.defaultName), std::move (buildingData.description));
		cDynamicUnitData dynamicData = createDynamicUnitData (buildingData.id, buildingData.dynamicData);
		staticData.buildingData = buildingData.staticBuildingData;

		UnitsDataGlobal.addData (staticData);
		UnitsDataGlobal.addData (dynamicData);
	}

	Log.info ("Buildings loaded: " + std::to_string (buildingsList.buildings.size()));
	return 1;
}

//------------------------------------------------------------------------------
/**
 * Loads all Vehicles (JSON data only, no graphics/sound)
 * @return 1 on success
 */
static int LoadVehicles()
{
	Log.info ("Loading Vehicles");

	auto vehicleJsonPath = cSettings::getInstance().getVehiclesPath() / "vehicles.json";
	if (!std::filesystem::exists (vehicleJsonPath))
	{
		Log.error ("vehicles.json doesn't exist at: " + vehicleJsonPath.string());
		return 0;
	}

	std::ifstream file (vehicleJsonPath);
	nlohmann::json json;

	if (!(file >> json))
	{
		Log.error ("Can't load " + vehicleJsonPath.string());
		return 0;
	}
	sVehiclesList vehiclesList;
	cJsonArchiveIn in (json);
	in >> vehiclesList;
	checkDuplicateId (vehiclesList.vehicles);

	for (const auto& p : vehiclesList.vehicles)
	{
		auto sVehiclePath = cSettings::getInstance().getVehiclesPath() / p.path;

		sInitialVehicleData vehicleData;
		LoadUnitData (vehicleData, sVehiclePath);

		if (p.id != vehicleData.id.secondPart)
		{
			Log.error ("ID " + std::to_string (p.id) + " isn't equal with ID from directory " + sVehiclePath.string());
			return 0;
		}
		else
		{
			Log.debug ("id " + std::to_string (p.id) + " verified for " + sVehiclePath.string());
		}
		if (!checkUniqueness (vehicleData.id)) return 0;

		cStaticUnitData staticData = createStaticUnitData (vehicleData.id, vehicleData.commonData, std::move (vehicleData.defaultName), std::move (vehicleData.description));
		cDynamicUnitData dynamicData = createDynamicUnitData (vehicleData.id, vehicleData.dynamicData);

		if (staticData.factorGround == 0 && staticData.factorSea == 0 && staticData.factorAir == 0 && staticData.factorCoast == 0)
		{
			Log.warn ("Unit " + staticData.getDefaultName() + " cannot move");
		}
		staticData.vehicleData = vehicleData.staticVehicleData;

		UnitsDataGlobal.addData (staticData);
		UnitsDataGlobal.addData (dynamicData);
	}

	UnitsDataGlobal.initializeIDData();

	Log.info ("Vehicles loaded: " + std::to_string (vehiclesList.vehicles.size()));
	return 1;
}

//------------------------------------------------------------------------------
/**
 * Loads the clan values and stores them in ClanDataGlobal
 * @return 1 on success
 */
static int LoadClans()
{
	auto clansPath = cSettings::getInstance().getDataDir() / "clans.json";

	if (!std::filesystem::exists (clansPath))
	{
		Log.error ("File doesn't exist: " + clansPath.string());
		return 0;
	}
	std::ifstream file (clansPath);
	nlohmann::json json;
	if (!(file >> json))
	{
		Log.error ("Can't load " + clansPath.string());
		return 0;
	}
	cJsonArchiveIn in (json);

	in >> ClanDataGlobal;

	UnitsDataGlobal.initializeClanUnitData (ClanDataGlobal);

	Log.info ("Clans loaded: " + std::to_string (ClanDataGlobal.getClans().size()));
	return 1;
}

//------------------------------------------------------------------------------
// Loads all relevant game data from JSON files:
// - Vehicles (from data/vehicles/)
// - Buildings (from data/buildings/)
// - Clans (from data/clans.json)
//
// The includingUiData parameter is ignored in the GDExtension build.
// No graphics, sound, fonts, or language files are loaded.
eLoadingState LoadData (bool /*includingUiData*/)
{
	Log.info ("=== LoadData: Loading M.A.X.R. game data (JSON only) ===");
	Log.info ("Data dir: " + cSettings::getInstance().getDataDir().string());

	// Load Vehicles
	if (LoadVehicles() != 1)
	{
		Log.error ("Failed to load vehicles!");
		return eLoadingState::Error;
	}

	// Load Buildings
	if (LoadBuildings() != 1)
	{
		Log.error ("Failed to load buildings!");
		return eLoadingState::Error;
	}

	// Load Clan Settings
	if (LoadClans() != 1)
	{
		Log.error ("Failed to load clans!");
		return eLoadingState::Error;
	}

	Log.info ("=== LoadData complete ===");
	Log.info ("  Vehicles + Buildings: " + std::to_string (UnitsDataGlobal.getStaticUnitsData().size()) + " unit types");
	Log.info ("  Clans: " + std::to_string (UnitsDataGlobal.getNrOfClans()));

	return eLoadingState::Finished;
}
