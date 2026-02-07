// Stub for MaXtreme GDExtension
// Minimal sVehicleUIStaticData so data.json "graphic" fields can be deserialized
// without pulling in SDL graphics code.
#ifndef MAXTREME_RESOURCES_VEHICLEUIDATA_H
#define MAXTREME_RESOURCES_VEHICLEUIDATA_H

#include "utility/serialization/serialization.h"

struct sVehicleUIStaticData
{
	bool buildUpGraphic = false;
	bool hasDamageEffect = false;
	bool hasOverlay = false;
	bool hasPlayerColor = false;
	bool isAnimated = false;
	int hasFrames = 0;

	template <typename Archive>
	void serialize (Archive& archive)
	{
		// clang-format off
		archive & NVP (buildUpGraphic);
		archive & NVP (hasDamageEffect);
		archive & NVP (hasOverlay);
		archive & NVP (hasPlayerColor);
		archive & NVP (isAnimated);
		archive & NVP (hasFrames);
		// clang-format on
	}
};

#endif // MAXTREME_RESOURCES_VEHICLEUIDATA_H
