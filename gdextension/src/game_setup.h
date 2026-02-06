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
/// Creates all the data structures needed to start a game:
/// unit definitions, map, game settings, players, and landing configuration.
/// Directly places starting units on the map for each player.
class GameSetup : public RefCounted {
    GDCLASS(GameSetup, RefCounted)

private:
    /// Creates a minimal but complete set of unit data for testing.
    /// Includes: Constructor, Tank, Surveyor, Engineer + alien units
    /// + Small Generator, Mining Station, Alien Factory, Connector
    static std::shared_ptr<cUnitsData> create_test_units_data();

    /// Creates a minimal WRL map file at the given path and loads it.
    /// The map is a flat ground map of the given size (must be power of 2).
    static std::shared_ptr<cStaticMap> create_and_load_flat_map(int size);

    /// Writes a minimal WRL format binary file to the given path.
    /// Returns true on success.
    static bool write_wrl_file(const std::filesystem::path& path, int size);

protected:
    static void _bind_methods();

public:
    GameSetup();
    ~GameSetup();

    /// Start a new test game with a 64x64 programmatic map and two players.
    /// This is the quickest way to get a running game for testing.
    /// Returns a Dictionary with game info on success.
    static Dictionary setup_test_game(cModel& model);

    /// Start a new game with custom parameters.
    /// player_names: Array of String player names
    /// player_colors: Array of Color player colors
    /// map_size: int (must be power of 2: 32, 64, 128, 256)
    /// start_credits: int
    /// Returns a Dictionary with game info on success.
    static Dictionary setup_custom_game(
        cModel& model,
        Array player_names,
        Array player_colors,
        int map_size,
        int start_credits
    );
};

} // namespace godot

#endif // MAXTREME_GAME_SETUP_H
