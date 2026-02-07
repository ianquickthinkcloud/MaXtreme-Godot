// Stub for MaXtreme GDExtension
// Minimal sBuildingUIStaticData so data.json "graphic" fields can be deserialized
// without pulling in SDL graphics code.
#ifndef MAXTREME_RESOURCES_BUILDINGUIDATA_H
#define MAXTREME_RESOURCES_BUILDINGUIDATA_H

#include "utility/serialization/serialization.h"

struct sBuildingUIStaticData
{
	bool hasBetonUnderground = false;
	bool hasClanLogos = false;
	bool hasDamageEffect = false;
	bool hasOverlay = false;
	bool hasPlayerColor = false;
	bool isAnimated = false;
	bool powerOnGraphic = false;

	template <typename Archive>
	void serialize (Archive& archive)
	{
		// clang-format off
		archive & NVP (hasBetonUnderground);
		archive & NVP (hasClanLogos);
		archive & NVP (hasDamageEffect);
		archive & NVP (hasOverlay);
		archive & NVP (hasPlayerColor);
		archive & NVP (isAnimated);
		archive & NVP (powerOnGraphic);
		// clang-format on
	}
};

#endif // MAXTREME_RESOURCES_BUILDINGUIDATA_H
