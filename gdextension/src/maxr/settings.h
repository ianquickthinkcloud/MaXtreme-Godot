// settings.h stub for MaXtreme GDExtension
// Provides a minimal cSettings singleton so game logic compiles.
// Settings will be managed by Godot's ProjectSettings/ConfigFile in later phases.
#ifndef MAXTREME_SETTINGS_STUB_H
#define MAXTREME_SETTINGS_STUB_H

#include <filesystem>
#include <string>

#include "utility/signal/signal.h"

struct sPlayerSettings;  // forward declared - full definition in playersettings.h

class cSettings
{
public:
	static cSettings& getInstance()
	{
		static cSettings instance;
		return instance;
	}

	void saveInFile() const {}
	bool isInitialized() const { return true; }

	/// Set the base data directory. All other paths are derived from this.
	/// Call this early (e.g. from GameEngine::initialize_engine()) with an
	/// absolute path obtained from Godot's ProjectSettings.globalize_path("res://data").
	void setDataDir(const std::filesystem::path& dir)
	{
		dataDir = dir;
		mapsPath = dataDir / "maps";
		fontPath = dataDir / "fonts";
		fxPath = dataDir / "fx";
		gfxPath = dataDir / "gfx";
		soundsPath = dataDir / "sounds";
		voicesPath = dataDir / "voices";
		musicPath = dataDir / "music";
		vehiclesPath = dataDir / "vehicles";
		buildingsPath = dataDir / "buildings";
		langPath = dataDir / "languages";
	}

	// Paths - return sensible defaults
	const std::filesystem::path& getMapsPath() const { return mapsPath; }
	const std::filesystem::path& getSavesPath() const { return savesPath; }
	const std::filesystem::path& getDataDir() const { return dataDir; }
	const std::filesystem::path& getHomeDir() const { return homeDir; }
	const std::filesystem::path& getFontPath() const { return fontPath; }
	const std::filesystem::path& getFxPath() const { return fxPath; }
	const std::filesystem::path& getGfxPath() const { return gfxPath; }
	const std::filesystem::path& getSoundsPath() const { return soundsPath; }
	const std::filesystem::path& getVoicesPath() const { return voicesPath; }
	const std::filesystem::path& getMusicPath() const { return musicPath; }
	const std::filesystem::path& getVehiclesPath() const { return vehiclesPath; }
	const std::filesystem::path& getBuildingsPath() const { return buildingsPath; }
	const std::filesystem::path& getLangPath() const { return langPath; }

	// Game settings
	bool isAnimations() const { return true; }
	bool isShadows() const { return true; }
	bool isAlphaEffects() const { return true; }
	bool isDamageEffects() const { return true; }
	bool isDamageEffectsVehicles() const { return true; }
	bool isMakeTracks() const { return true; }
	bool isAutosave() const { return true; }
	bool shouldAutosave() const { return true; }
	bool isDebug() const { return false; }
	bool isIntro() const { return false; }
	bool isFastMode() const { return false; }
	bool isDoPrescale() const { return false; }

	int getScrollSpeed() const { return 32; }

	const std::string& getLanguage() const { return language; }

	const std::string& getPlayerName() const { return playerName; }
	unsigned int getPlayerColor() const { return 0; }
	const std::string& getPort() const { return port; }
	const std::string& getIP() const { return ip; }

	const std::filesystem::path& getUserMapsDir() const { return userMapsDir; }

	// Defined in settings_stub.cpp to avoid circular include with sPlayerSettings
	sPlayerSettings getPlayerSettings() const;

	mutable cSignal<void()> animationsChanged;

private:
	cSettings()
	{
		dataDir = "data";
		mapsPath = dataDir / "maps";
		savesPath = "saves";
		homeDir = ".";
		fontPath = dataDir / "fonts";
		fxPath = dataDir / "fx";
		gfxPath = dataDir / "gfx";
		soundsPath = dataDir / "sounds";
		voicesPath = dataDir / "voices";
		musicPath = dataDir / "music";
		vehiclesPath = dataDir / "vehicles";
		buildingsPath = dataDir / "buildings";
		langPath = dataDir / "languages";
		userMapsDir = "";
	}

	std::filesystem::path dataDir;
	std::filesystem::path mapsPath;
	std::filesystem::path savesPath;
	std::filesystem::path homeDir;
	std::filesystem::path fontPath;
	std::filesystem::path fxPath;
	std::filesystem::path gfxPath;
	std::filesystem::path soundsPath;
	std::filesystem::path voicesPath;
	std::filesystem::path musicPath;
	std::filesystem::path vehiclesPath;
	std::filesystem::path buildingsPath;
	std::filesystem::path langPath;
	std::filesystem::path userMapsDir;

	std::string language = "en";
	std::string playerName = "Player";
	std::string port = "58600";
	std::string ip = "127.0.0.1";
};

#endif // MAXTREME_SETTINGS_STUB_H
