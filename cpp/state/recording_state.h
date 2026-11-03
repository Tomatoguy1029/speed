#pragma once
#include <cstdint>
#include <map>
#include <string>
#include <tuple>
namespace speed {
using RecordingEnemyKey=std::tuple<std::string,std::string,bool>;
using RecordingDamageKey=std::tuple<std::string,RecordingEnemyKey,std::string>;
struct RecordingDamage {int64_t hits=0;double resolved=0,applied=0,overkill=0,discarded=0;};
struct RecordingLife {
    int64_t spawned=0,killed=0,removed=0,alive_at_end=0,unknown_spawn=0;
    double life_world_sum=0,first_hit_to_kill_world_sum=0,max_hp_at_spawn_sum=0;
    int64_t life_world_count=0,first_hit_to_kill_count=0,max_hp_at_spawn_count=0;
};
struct RecordingEnemy {RecordingEnemyKey key;double born=0,first_hit=-1;bool observed=false;};
struct RecordingStrong {
    std::string enemy,result="alive",killed_by;
    double spawned=0,life=0,weapon_damage=0;int64_t rams=0;
    std::map<std::string,double> by_cause;
};
// 診断の詳細度・上限から独立した、録画区間内の通常計測。値だけなので保持・復帰も独立する。
struct RecordingState {
    bool active=false;
    std::map<RecordingDamageKey,RecordingDamage> effective_damage;
    std::map<RecordingEnemyKey,RecordingLife> enemy_life;
    std::map<std::tuple<std::string,std::string,std::string>,int64_t> enemy_contacts;
    std::map<int64_t,RecordingEnemy> seen;
    std::map<int64_t,RecordingStrong> strong;
    std::map<std::string,int64_t> kills,kills_by;
    std::map<std::string,double> dealt,damage;
    std::map<double,int64_t> budget_observations;
    std::string last_hurt_cause,last_hurt_source;
};
}
