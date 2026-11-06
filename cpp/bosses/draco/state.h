#pragma once
#include "../../state/boss_states.h"
#include "../hydra/state.h"
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <variant>
#include <vector>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/vector2.hpp>
namespace speed {
struct DracoBiteState {godot::Vector2 origin,retracted,strike;std::vector<godot::Vector2> base,landed;};
struct DracoBreathState {std::vector<RockHandle> rocks;std::vector<godot::Vector2> destinations,base,recovering;std::vector<double> burn;std::vector<uint8_t> launched,broken;godot::Vector2 mouth;double axis=0,fan_angle=0,rock_aim=0;};
struct DracoFlyingMeteor {RockHandle rock;godot::Vector2 direction;double born=0,life=0;};
struct DracoStagingState {uint8_t phase=0;bool enter=false;double side=1,height=0,distance=0,exit_angle=0,away_angle=0,exit_time=0,entry_time=0;godot::Vector2 entry_from,entry_to;std::vector<godot::Vector2> trail,points;};
struct DracoChargeState {DracoStagingState staging;godot::Vector2 origin,destination,settled;bool positioned=false;};
struct DracoLeapState {DracoStagingState staging;godot::Vector2 origin,destination,takeoff,landed;std::vector<godot::Vector2> base;bool positioned=false;};
struct DracoTailSlamState {godot::Vector2 origin,target;double axis=0,mirror=1;std::vector<godot::Vector2> base;bool fired=false;};
struct DracoTailSweepState {godot::Vector2 origin;double facing=0;std::vector<godot::Vector2> base,prior,area;};
struct DracoStarFanState {std::vector<godot::Vector2> positions;std::vector<double> angles;bool fired=false;};
struct DracoRiftTear {godot::Vector2 from,to;double fire=0,width=0,hold=0;uint32_t seed=0;AttackHandle slash,wall;};
struct DracoRiftSwipe {double fire=0,aim=0,side=1;};
struct DracoRiftsState {DracoStagingState staging;std::vector<DracoRiftTear> tears;std::vector<DracoRiftSwipe> swipes;godot::Vector2 center;bool ended=false;};
struct DracoArrowImpact {godot::Vector2 position;double wait=0,warn=0,age=0;bool locked=false;};
struct DracoPicaroWallState {uint32_t shots=0;double axis=0;bool roared=false;std::vector<DracoArrowImpact> impacts;};
struct DracoSpiralState {
    DracoStagingState return_staging;
    godot::Vector2 center,held_ship,outside,control,inside,recovery;
    double extent=1000,horizontal=1000,length=9000,inner=0.2,coil=1.2,pause=1.6,first=0.42,second=0.54,bend=0.24,shrink=2,offset=320,bend_radius=220,zoom=1,departure_time=0,departure_angle=0,hp_before=0;
    bool camera_before=false,controls_before=false,protection_before=false,departing=true,holding=false,charging=false,trapped=false,trapped_hit=false,hp_sampled=false;
    std::vector<godot::Vector2> points,trail,entry,coiled;
    godot::Vector2 pull_from;
    std::vector<AttackHandle> walls;
};
struct DracoSideEntryState {godot::Vector2 origin,outside,inside;double angle=0,facing=0,side=1;};
struct DracoInhaleState {DracoSideEntryState staging;uint32_t stars=0;bool spent=false,caught=false,spat=false;double release_at=0;AttackHandle beam;godot::Vector2 direction;};
struct DracoCloneUnit;
struct DracoClonesState {std::vector<DracoCloneUnit> units;godot::Vector2 center;double axis=0;bool roared=false,ended=false;};
struct DracoTechniqueState {double stage_time=0;std::vector<godot::Vector2> warning,attack;double warning_width=0,attack_width=0;std::vector<std::vector<godot::Vector2>> warning_paths;std::variant<DracoBiteState,DracoBreathState,DracoChargeState,DracoLeapState,DracoTailSlamState,DracoTailSweepState,DracoStarFanState,DracoRiftsState,DracoPicaroWallState,DracoInhaleState,DracoSpiralState,DracoClonesState> move;};
struct DracoPicaroMember {
    EnemyHandle actor;
    std::vector<EnemyHandle> parts,clone_parts;
    double born=0,angle=0;
    uint32_t stars=1;
};
struct DracoCinematicState {
    bool saved=false,controls_locked=false,protected_ship=false,camera=false,hide=false;
    double bars=0,zoom=1,world_scale=1;
    godot::Vector2 center,half,heading;
};
struct DracoIntroState {
    struct Held {EnemyHandle actor;bool held=false;};
    DracoCinematicState saved;
    std::vector<Held> held;
    bool active=false;
    uint8_t stage=0;
    double time=0,rift=0,eyes=0,chest=0,emerged=0,zoom=1,facing=0,guard=0;
    BossMode mode=BossMode::Idle;
    godot::Vector2 origin,ship,camera,center,rift_center;
};
enum class DracoCycleStage : uint8_t { None,Roar,Collect,WaitBeams,Return,Generate };
struct DracoCycleState {
    DracoCinematicState saved;
    DracoCycleStage stage=DracoCycleStage::None;
    bool first=false;
    uint32_t generated=0;
    double time=0,next_cycle=12,zoom=1,return_depth=1,return_alpha=1,return_angle=0;
    godot::Vector2 home,from,return_from;
};
struct DracoImpact {godot::Vector2 position;double time=0,radius=0;uint32_t technique=0;};
struct DracoClosingWall {AttackHandle attack;godot::Vector2 from;double time=0.3,duration=0.3,delay=0,length=0,half_width=0,angle=0;};
enum class DracoFinaleStage : uint8_t {None,Release,Combine,Pose,Input,Strikes,Last,Sight,Split,Explode};
struct DracoFinaleTrail {std::vector<godot::Vector2> points;double time=0;};
struct DracoFinaleState {
    DracoCinematicState saved;
    DracoFinaleStage stage=DracoFinaleStage::None;
    bool active=false,completed=false,began=false,finish_before=false;
    std::vector<std::string> modules_before;
    double time=0,zoom=1,assembly_zoom=1,dim=0,split=0,radius=0,combine=0,original_angle=0,original_guard=0;
    int32_t last_strike=-1;
    godot::Vector2 center,core,core_from,camera_from,assembly_camera,original_pos,original_ship,original_velocity;
    std::vector<godot::Vector2> guide,strokes,line,pose_from,pose;
    std::vector<DracoFinaleTrail> trails;
};
struct DracoBodyState {
    DracoFinaleState finale;
    uint32_t lab_inhale_stars=12;
    std::vector<DracoClosingWall> closing_walls;
    std::vector<RockHandle> placed_meteors;
    std::vector<DracoFlyingMeteor> meteors;
    std::vector<DracoImpact> impacts;
    DracoCycleState cycle;
    DracoIntroState intro;
    std::vector<DracoPicaroMember> picaro;
    std::vector<EnemyHandle> picaro_pending;
    bool picaro_attacking=true;
    std::vector<godot::Vector2> trail,pose,override_points;
    double width=154,head_scale=1.35,depth=1,alpha=1;
};
struct DracoCloneUnit {TechniqueState inner;HydraNeckState neck;std::vector<EnemyHandle> parts;std::vector<godot::Vector2> points,trail;double face=0;godot::Vector2 origin;uint32_t index=0;bool entry_hit=false;};
}
