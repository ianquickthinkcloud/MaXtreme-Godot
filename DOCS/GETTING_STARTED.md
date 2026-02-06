# MaXtreme - Getting Started Guide

## How to Load and Run MaXtreme in Godot

---

### Prerequisites

You need the following installed on your machine:

| Tool | Version | Purpose |
|------|---------|---------|
| **Godot Engine** | 4.5 or 4.6 | Game engine (download from [godotengine.org](https://godotengine.org/download)) |
| **SCons** | 4.x | Build system for the C++ extension (`pip install scons` or `brew install scons`) |
| **C++ compiler** | C++20 capable | Xcode Command Line Tools (macOS), MSVC (Windows), GCC/Clang (Linux) |

> **Important:** Download the **Standard** version of Godot (not .NET). You need the **editor** build, not the export templates.

---

### Step 1: Clone the Repository

```bash
git clone --recurse-submodules https://github.com/ianquickthinkcloud/MaXtreme-Godot.git
cd MaXtreme-Godot
```

If you already cloned without `--recurse-submodules`:

```bash
git submodule update --init --recursive
```

---

### Step 2: Build the GDExtension (C++ Engine)

The M.A.X.R. game engine is compiled as a Godot GDExtension. You must build it before running the project.

#### macOS (Apple Silicon / M-series)

```bash
cd gdextension
scons platform=macos arch=arm64 target=template_debug
```

#### macOS (Intel)

```bash
cd gdextension
scons platform=macos arch=x86_64 target=template_debug
```

#### Linux

```bash
cd gdextension
scons platform=linux target=template_debug
```

#### Windows

Open a **Developer Command Prompt for Visual Studio**, then:

```cmd
cd gdextension
scons platform=windows target=template_debug
```

**Expected output:** The build takes 1-3 minutes. You should see:

```
Linking Shared Library .../bin/libmaxtreme.macos.template_debug.framework/libmaxtreme.macos.template_debug
scons: done building targets.
```

The compiled library goes into the `bin/` folder at the project root.

---

### Step 3: Open in Godot

1. Launch **Godot Engine** (the editor)
2. Click **Import** on the Project Manager screen
3. Navigate to the `MaXtreme-Godot` folder and select the `project.godot` file
4. Click **Import & Edit**

Godot will scan the project and load the GDExtension automatically from `bin/maxtreme.gdextension`.

---

### Step 4: Run the Game

Press **F5** (or click the Play button ▶ in the top-right corner).

You should see:

- A **green tile grid** (64x64 map) filling the viewport
- **Blue units** (Player 1) and **Red units** (Player 2) placed on the map
- A **HUD** at the top showing turn info and player stats
- An **END TURN** button at the bottom
- A **unit info panel** (bottom-left, appears when you select a unit)

---

### Step 5: Play!

| Action | Control |
|--------|---------|
| **Select a unit** | Left-click on it |
| **Move selected unit** | Left-click on an empty tile |
| **Attack an enemy** | Left-click on an enemy unit (with yours selected) |
| **Deselect** | Right-click anywhere |
| **Pan camera** | WASD or Arrow keys |
| **Pan camera (drag)** | Middle-mouse-button drag |
| **Pan camera (edge)** | Move mouse to screen edges |
| **Zoom in/out** | Mouse scroll wheel |
| **End turn** | Click the END TURN button |

---

### Troubleshooting

#### "GameEngine class not found" or missing class errors

The GDExtension hasn't been built or isn't being found. Make sure:
- You completed Step 2 (the build)
- The `bin/` folder contains the compiled library for your platform
- The file `bin/maxtreme.gdextension` exists

#### Build fails with "godot-cpp not found"

You need to initialise the git submodule:

```bash
git submodule update --init --recursive
```

#### Build fails with compiler errors

Make sure you have a C++20-capable compiler:
- **macOS:** `xcode-select --install`
- **Linux:** `sudo apt install g++-12` (or newer)
- **Windows:** Install Visual Studio 2022 with C++ workload

#### Black screen or nothing renders

Check the Godot Output panel (bottom of the editor) for error messages. Common causes:
- The main scene isn't set correctly (should be `res://scenes/game/main_game.tscn`)
- The GDExtension binary doesn't match your platform/architecture

#### Want to run the unit tests instead?

Change the main scene in Project Settings:
1. Go to **Project > Project Settings > Application > Run**
2. Change **Main Scene** to `res://scenes/test/test_engine.tscn`
3. Press F5

This runs the automated test suite that verifies the C++ engine bridge.

---

### Project Structure

```
MaXtreme-Godot/
├── project.godot              # Godot project file
├── bin/                       # Compiled GDExtension binaries
│   ├── maxtreme.gdextension  # Extension configuration
│   └── libmaxtreme.*.framework/  # Compiled C++ library
├── scenes/
│   ├── game/
│   │   └── main_game.tscn    # Main game scene (the game!)
│   └── test/
│       └── test_engine.tscn  # Automated tests
├── scripts/
│   ├── game/
│   │   ├── main_game.gd      # Main game logic
│   │   ├── game_camera.gd    # Camera (pan/zoom)
│   │   ├── game_hud.gd       # HUD overlay
│   │   ├── map_renderer.gd   # Map tile drawing
│   │   └── unit_renderer.gd  # Unit shape drawing
│   └── test/
│       └── test_engine.gd    # Engine test script
├── gdextension/
│   ├── SConstruct             # Build script
│   ├── godot-cpp/             # Godot C++ bindings (submodule)
│   └── src/
│       ├── game_engine.h/cpp  # Main bridge class
│       ├── game_map.h/cpp     # Map wrapper
│       ├── game_player.h/cpp  # Player wrapper
│       ├── game_unit.h/cpp    # Unit wrapper
│       ├── game_actions.h/cpp # Action system wrapper
│       ├── game_setup.h/cpp   # Game initialization
│       └── maxr/              # Original M.A.X.R. C++ engine
└── DOCS/                      # Documentation
```

---

### What You're Looking At

This is a **Godot 4.6 port** of M.A.X.R. (Mechanized Assault & eXploration Reloaded), the open-source remake of the 1996 classic M.A.X. The original C++ game engine has been preserved as a GDExtension, with Godot handling all rendering, input, and UI.

Currently, the visual prototype uses **placeholder graphics** (colored shapes). The game logic underneath is the real deal - the same simultaneous turn-based engine that powered the original game.
