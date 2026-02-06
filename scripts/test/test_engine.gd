extends Node

## Test script to verify the MaXtreme GDExtension loads and works.
## This is Phase 1 proof-of-life. Run this scene to verify the C++ bridge works.

func _ready() -> void:
	print("=== MaXtreme GDExtension Test ===")
	print("")

	# Create the GameEngine node from the GDExtension
	var engine = GameEngine.new()
	add_child(engine)

	# Test basic methods
	print("Version:     ", engine.get_engine_version())
	print("Status:      ", engine.get_engine_status())
	print("Initialized: ", engine.is_engine_initialized())

	print("")
	print("Calling initialize_engine()...")
	engine.initialize_engine()

	print("")
	print("Status:      ", engine.get_engine_status())
	print("Initialized: ", engine.is_engine_initialized())

	print("")
	print("=== GDExtension bridge is WORKING! ===")
	print("=== Phase 1a complete. Ready for Phase 1b. ===")
