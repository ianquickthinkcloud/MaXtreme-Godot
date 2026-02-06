#ifndef MAXTREME_GAME_ENGINE_H
#define MAXTREME_GAME_ENGINE_H

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/string.hpp>

#include <memory>

// Forward declarations of M.A.X.R. core types
class cModel;
class cStaticMap;
class cUnitsData;

namespace godot {

/// GameEngine - The main bridge between Godot and the M.A.X.R. C++ engine.
///
/// Phase 1b: Proves the core C++ engine compiles and is accessible from GDScript.
/// Phase 2+: Will wrap cModel, cServer, actions, pathfinding, etc.
class GameEngine : public Node {
    GDCLASS(GameEngine, Node)

private:
    bool engine_initialized = false;
    std::unique_ptr<cModel> model;

protected:
    static void _bind_methods();

public:
    GameEngine();
    ~GameEngine();

    // Phase 1: Proof of life
    String get_engine_version() const;
    String get_engine_status() const;
    bool is_engine_initialized() const;
    void initialize_engine();

    // Phase 1b: Core engine access
    int get_turn_number() const;
    String get_map_name() const;
    int get_player_count() const;
};

} // namespace godot

#endif // MAXTREME_GAME_ENGINE_H
