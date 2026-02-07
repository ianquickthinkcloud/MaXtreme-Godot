// loaddata.h - Adapted for MaXtreme GDExtension
// Based on maxr-release-0.2.17 loaddata.h
// Loads JSON game data (vehicles, buildings, clans) without any UI/graphics/sound.

#ifndef resources_loaddataH
#define resources_loaddataH

enum class eLoadingState
{
	Error,
	Finished
};

/**
 * Loads all game data from JSON files (vehicles, buildings, clans).
 * Populates UnitsDataGlobal and ClanDataGlobal.
 * The includingUiData parameter is kept for API compatibility but is always
 * treated as false in the GDExtension build (no graphics/sound loading).
 */
eLoadingState LoadData (bool includingUiData = false);

#endif
