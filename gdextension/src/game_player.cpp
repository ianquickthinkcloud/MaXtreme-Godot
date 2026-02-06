#include "game_player.h"

#include <godot_cpp/variant/utility_functions.hpp>

#include "game/data/player/player.h"

using namespace godot;

void GamePlayer::_bind_methods() {
    // Identity
    ClassDB::bind_method(D_METHOD("get_name"), &GamePlayer::get_name);
    ClassDB::bind_method(D_METHOD("get_id"), &GamePlayer::get_id);
    ClassDB::bind_method(D_METHOD("get_color"), &GamePlayer::get_color);
    ClassDB::bind_method(D_METHOD("get_clan"), &GamePlayer::get_clan);

    // Economy
    ClassDB::bind_method(D_METHOD("get_credits"), &GamePlayer::get_credits);
    ClassDB::bind_method(D_METHOD("get_score"), &GamePlayer::get_score);

    // Unit counts
    ClassDB::bind_method(D_METHOD("get_vehicle_count"), &GamePlayer::get_vehicle_count);
    ClassDB::bind_method(D_METHOD("get_building_count"), &GamePlayer::get_building_count);

    // Research
    ClassDB::bind_method(D_METHOD("get_research_centers_working"), &GamePlayer::get_research_centers_working);

    // Game state
    ClassDB::bind_method(D_METHOD("is_defeated"), &GamePlayer::is_defeated);
    ClassDB::bind_method(D_METHOD("has_finished_turn"), &GamePlayer::has_finished_turn);

    // Statistics
    ClassDB::bind_method(D_METHOD("get_built_vehicles_count"), &GamePlayer::get_built_vehicles_count);
    ClassDB::bind_method(D_METHOD("get_lost_vehicles_count"), &GamePlayer::get_lost_vehicles_count);
    ClassDB::bind_method(D_METHOD("get_built_buildings_count"), &GamePlayer::get_built_buildings_count);
    ClassDB::bind_method(D_METHOD("get_lost_buildings_count"), &GamePlayer::get_lost_buildings_count);
}

GamePlayer::GamePlayer() {}
GamePlayer::~GamePlayer() {}

void GamePlayer::set_internal_player(std::shared_ptr<cPlayer> p) {
    player = p;
}

// --- Identity ---

String GamePlayer::get_name() const {
    if (!player) return String("");
    return String(player->getName().c_str());
}

int GamePlayer::get_id() const {
    if (!player) return -1;
    return player->getId();
}

Color GamePlayer::get_color() const {
    if (!player) return Color(1, 1, 1);
    const auto& c = player->getColor();
    return Color(c.r / 255.0f, c.g / 255.0f, c.b / 255.0f);
}

int GamePlayer::get_clan() const {
    if (!player) return -1;
    return player->getClan();
}

// --- Economy ---

int GamePlayer::get_credits() const {
    if (!player) return 0;
    return player->getCredits();
}

int GamePlayer::get_score() const {
    if (!player) return 0;
    return player->getScore();
}

// --- Unit counts ---

int GamePlayer::get_vehicle_count() const {
    if (!player) return 0;
    return static_cast<int>(player->getVehicles().size());
}

int GamePlayer::get_building_count() const {
    if (!player) return 0;
    return static_cast<int>(player->getBuildings().size());
}

// --- Research ---

int GamePlayer::get_research_centers_working() const {
    if (!player) return 0;
    return player->getResearchCentersWorkingTotal();
}

// --- Game state ---

bool GamePlayer::is_defeated() const {
    if (!player) return false;
    return player->isDefeated;
}

bool GamePlayer::has_finished_turn() const {
    if (!player) return false;
    return player->getHasFinishedTurn();
}

// --- Statistics ---

int GamePlayer::get_built_vehicles_count() const {
    if (!player) return 0;
    return static_cast<int>(player->getGameOverStat().builtVehiclesCount);
}

int GamePlayer::get_lost_vehicles_count() const {
    if (!player) return 0;
    return static_cast<int>(player->getGameOverStat().lostVehiclesCount);
}

int GamePlayer::get_built_buildings_count() const {
    if (!player) return 0;
    return static_cast<int>(player->getGameOverStat().builtBuildingsCount);
}

int GamePlayer::get_lost_buildings_count() const {
    if (!player) return 0;
    return static_cast<int>(player->getGameOverStat().lostBuildingsCount);
}
