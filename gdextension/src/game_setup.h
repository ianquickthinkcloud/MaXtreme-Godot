#ifndef MAXTREME_GAME_SETUP_H
#define MAXTREME_GAME_SETUP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/vector2i.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/dictionary.hpp>

#include <memory>
#include <string>
#include <vector>
#include <filesystem>

class cModel;
class cUnitsData;
class cStaticMap;
class cGameSettings;

namespace godot {

/// GameSetup - Handles game initialization and setup.
///
/// Uses the real M.A.X.R. data loading system (LoadData) to populate
/// UnitsDataGlobal with all 35 vehicles, 33+ buildings, and 8 clans
/// from JSON files on disk. Loads real WRL maps from data/maps/.
class GameSetup : public RefCounted {
    GDCLASS(GameSetup, RefCounted)

private:
    /// Whether LoadData() has been called successfully
    static bool data_loaded;

    /// Loads a real WRL map file from data/maps/
    static std::shared_ptr<cStaticMap> load_map(const std::string& map_filename);

    /// Writes a minimal WRL format binary file to the given path (fallback).
    static bool write_wrl_file(const std::filesystem::path& path, int size);

    /// Creates a minimal WRL map file at the given path and loads it (fallback).
    static std::shared_ptr<cStaticMap> create_and_load_flat_map(int size);

protected:
    static void _bind_methods();

public:
    GameSetup();
    ~GameSetup();

    /// Ensure game data (vehicles, buildings, clans) is loaded from JSON.
    /// Safe to call multiple times - only loads once.
    /// Returns true if data was loaded successfully.
    static bool ensure_data_loaded();

    /// Get list of available map filenames from data/maps/
    static Array get_available_maps();

    /// Get list of available clan names from loaded clan data
    static Array get_available_clans();

    /// Get detailed info about loaded unit data
    static Dictionary get_unit_data_info();

    /// Start a new test game with a real map and two players.
    /// Uses the first available map (or fallback flat map).
    static Dictionary setup_test_game(cModel& model);

    /// Start a new game with custom parameters.
    /// map_name: String filename of the map (e.g. "Delta.wrl"), or "" for first available
    /// player_names: Array of String player names
    /// player_colors: Array of Color player colors
    /// player_clans: Array of int clan indices (-1 = no clan)
    /// start_credits: int
    /// Returns a Dictionary with game info on success.
    static Dictionary setup_custom_game(
        cModel& model,
        String map_name,
        Array player_names,
        Array player_colors,
        Array player_clans,
        int start_credits
    );

    /// Start a new game with full game settings.
    /// game_settings: Dictionary with all configuration options:
    ///   map_name: String, player_names: Array, player_colors: Array,
    ///   player_clans: Array, start_credits: int,
    ///   game_type: String ("simultaneous"/"turns"/"hotseat"),
    ///   victory_type: String ("death"/"turns"/"points"),
    ///   victory_turns: int, victory_points: int,
    ///   metal_amount: String, oil_amount: String, gold_amount: String,
    ///   resource_density: String,
    ///   bridgehead_type: String ("mobile"/"definite"),
    ///   alien_enabled: bool, clans_enabled: bool,
    ///   turn_limit_active: bool, turn_limit_seconds: int,
    ///   turn_deadline_active: bool, turn_deadline_seconds: int,
    ///   player_landing_units: Array of Arrays of Dicts {id_first, id_second, cargo}
    ///   player_landing_positions: Array of Vector2i
    static Dictionary setup_custom_game_ex(
        cModel& model,
        Dictionary game_settings
    );

    // --- Phase 18: Pre-game setup data ---

    /// Get all purchasable vehicle types for the unit purchase screen.
    /// clan: clan index (-1 for base stats, 0-7 for clan-modified stats)
    /// Returns Array of Dictionaries with unit info (id, name, cost, stats).
    static Array get_purchasable_vehicles(int clan = -1);

    /// Get the free initial landing units for a given bridgehead type.
    /// For Mobile bridgehead, returns empty (player buys everything).
    /// For Definite bridgehead, returns Constructor + Engineer + Surveyor (+ extras for clan 7).
    /// Returns Array of Dictionaries: {id_first, id_second, name, cargo}
    static Array get_initial_landing_units(int clan, int start_credits, const String& bridgehead_type);

    /// Get detailed clan data including stat modifications per unit type.
    /// Returns Array of Dictionaries with clan info and modifications.
    static Array get_clan_details();

    /// Check if a position is valid for landing on a given map.
    /// Loads the map temporarily if needed. Simple terrain check.
    /// Returns true if the position is on passable ground.
    static bool check_landing_position(const String& map_name, Vector2i pos);
};

} // namespace godot

#endif // MAXTREME_GAME_SETUP_H
