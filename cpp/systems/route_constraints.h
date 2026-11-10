#pragma once
#include <godot_cpp/variant/vector2.hpp>
#include <vector>
#include <cstdint>
#include <limits>
namespace speed {
class RunRuntime;
struct RouteOptions {double margin=20,window=0,draw_seconds=0.5,exit_clearance=0;std::vector<int64_t> future_ticks;bool scheduled=false;};
enum class RouteReason {InvalidPath,OverBudget,LowFuel,LinkTooFar,FieldEdge,Body,Gate,Strong,MovingEnemy,MovingTerrain,FutureCommands,Equipment,FutureTerrain,HomingBullet,AttachedHazard,AutoSpawn,Scheduled,Bullet,Hazard};
enum class RouteStatus {Invalid,Static,Unfound,Window,Unsupported};
struct RouteObstacle {RouteReason reason=RouteReason::Body;godot::Vector2 position;int64_t id=0;};
struct RouteContext {
    struct Body {godot::Vector2 position;double radius=0;};
    struct Enemy {int64_t id=0;godot::Vector2 position,velocity;double radius=0,hp=0,armor=0,speed=0;uint32_t gate=0;bool boss=false,simple=false,chain=false,split=false,life=false;};
    struct Bullet {godot::Vector2 position,velocity;double radius=0;bool homing=false;int64_t id=0;};
    struct Hazard {godot::Vector2 position,end;double radius=0;bool circle=true,attached=false;int64_t id=0;};
    godot::Vector2 ship_position;
    double ship_radius=0,field_radius=0,point_step=0,zoom=1,fuel=0,fuel_max=0,fuel_capacity=1,boost_min_cost=0,boost_min_q=0,boost_cost_ratio=1;
    double draw_length=1,max_speed=1,base_speed=1,length_mult=1,confirm_delay=0,run_time=0,hitstop_cap=0,time_scale=1,scale_min=1,pending_world=0;
    double attack=0,window_attack=0,body_speed=0,comet_time=std::numeric_limits<double>::infinity(),gravity_time=std::numeric_limits<double>::infinity();
    int64_t tick=0,history_hz=120,equipment_count=0,well_count=0,rock_count=0;
    bool hero=false,auto_spawn=false;
    std::vector<Body> bodies;std::vector<Enemy> enemies;std::vector<Bullet> bullets;std::vector<Hazard> hazards;
};
struct RouteResult {
    RouteStatus status=RouteStatus::Invalid;bool valid=false;
    double length=0,budget=0,radius=0,horizon=0;
    std::vector<RouteObstacle> blockers,unsupported;std::vector<int64_t> fodder;
};
class RouteConstraints {
public:
    static RouteContext context(const RunRuntime &);
    static double distance(godot::Vector2,const std::vector<godot::Vector2> &);
    static RouteResult validate(const RouteContext &,const std::vector<godot::Vector2> &,const RouteOptions &);
};
}
