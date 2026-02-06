#ifndef MAXTREME_GAME_ENGINE_H
#define MAXTREME_GAME_ENGINE_H

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/string.hpp>

namespace godot {

/// GameEngine - The main bridge between Godot and the M.A.X.R. C++ engine.
///
/// Phase 1: Minimal proof-of-life. Returns version info and basic status.
/// Phase 2+: Will wrap cModel, cServer, actions, pathfinding, etc.
class GameEngine : public Node {
    GDCLASS(GameEngine, Node)

private:
    bool engine_initialized = false;

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
};

} // namespace godot

#endif // MAXTREME_GAME_ENGINE_H
