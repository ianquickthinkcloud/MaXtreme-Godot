// settings_stub.cpp - Implementation for stub settings methods
#include "settings.h"
#include "game/data/player/playersettings.h"

sPlayerSettings cSettings::getPlayerSettings() const
{
	sPlayerSettings s;
	s.name = playerName;
	s.color = cRgbColor (0, 0, 255);
	return s;
}
