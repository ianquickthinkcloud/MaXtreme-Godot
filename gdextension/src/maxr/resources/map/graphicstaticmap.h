// resources/map/graphicstaticmap.h stub for MaXtreme GDExtension
// Graphics are handled by Godot's rendering system.
// This stub provides the minimal class definition so cStaticMap compiles.
#ifndef MAXTREME_GRAPHIC_STATIC_MAP_STUB_H
#define MAXTREME_GRAPHIC_STATIC_MAP_STUB_H

#include <vector>

class cStaticMap;

struct sGraphicTile
{
	static constexpr int tilePixelHeight = 64;
	static constexpr int tilePixelWidth = 64;
};

// Forward declarations for SDL stubs
struct SDL_RWops;

class cGraphicStaticMap
{
public:
	explicit cGraphicStaticMap (const cStaticMap* map) : map (map) {}

	// These accept SDL_RWops* to match the original signatures used in map.cpp
	void loadPalette (SDL_RWops* /*file*/, std::size_t /*palettePos*/, std::size_t /*numTerrains*/) {}
	bool loadTile (SDL_RWops* /*file*/, std::size_t /*graphicsPos*/, int /*index*/) { return true; }

	const sGraphicTile& getTile (int /*index*/) const
	{
		static sGraphicTile dummy;
		return dummy;
	}
	void createBigSurface() {}
	void generateNextAnimationFrame() {}

private:
	const cStaticMap* map = nullptr;
	std::vector<sGraphicTile> tiles;
};

#endif // MAXTREME_GRAPHIC_STATIC_MAP_STUB_H
