#pragma once
#include "../content/generated/combat_ids.h"
#include "../systems/timing.h"
#include "entity_store.h"
#include "forward_weapon_state.h"
#include "equipment_level.h"
#include <cstdint>
#include <vector>
#include <unordered_set>
#include <unordered_map>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/color.hpp>
namespace speed {
struct RearWeaponState : ForwardWeaponState {
    uint32_t definition=0,color=0;
    double mount_x=0,mount_y=0,muzzle_distance=0;
};
struct ScatterWeaponState {
    bool ready=false;
    uint32_t definition=0,shots=0;
    IntervalTimer fire;
    double recoil=0,elapsed=0,base_interval=0,interval=0,damage=0,life=0,spread=0,knock=0;
};
struct BarrierWaveState {
    godot::Vector2 pos;
    double age=0,radius=0,damage=0,angle=0;
    bool broken=false;
    std::unordered_set<int64_t> hits;
};
struct BarrierWeaponState {
    bool ready=false;
    uint32_t definition=0;
    double restore_visual_age=1;
    double durability=-1,restore=0,maximum=0,revive=0,radius=0,damage=0,shell_radius=0,knock=0;
    std::vector<BarrierWaveState> waves;
};
struct MineState {
    godot::Vector2 pos,from,to;
    uint64_t id=0;
    double age=0,life=0,damage=0,radius=0;
    bool detonate=false;
};
struct MineVisual {godot::Vector2 pos;double radius=0,age=0;uint64_t id=0;};
struct MinesWeaponState {
    bool ready=false,chain=false;
    uint32_t definition=0,count=0,maximum=0;
    uint64_t serial=0,next_visual=1;
    double damage=0,radius=0,life=0,trigger=0,spread=0,range_min=0,range_max=0,duration_increment=0,knockback_increment=0,visual_life=0;
    std::vector<MineState> items;
    std::vector<MineVisual> visuals;
};
struct EndBlastPending {
    godot::Vector2 pos;
    double radius=0,damage=0,delay=0;
};
struct EndBlastVisual {
    godot::Vector2 pos;
    double radius=0,age=0;
    uint64_t id=0;
};
struct EndBlastWeaponState {
    bool ready=false;
    uint32_t definition=0,secondary=0;
    uint64_t next_visual=1;
    double radius=0,damage=0,secondary_radius=0,secondary_damage=0,secondary_delay=0,secondary_step=0,knock=0;
    std::vector<EndBlastPending> pending;
    std::vector<EndBlastVisual> visuals;
};
struct KnockbackVisual {godot::Vector2 pos;uint64_t id=0;bool hit=false;double born_world_time=0;};
struct KnockbackState {
    bool ready=false;
    uint32_t definition=0,chain_limit=0;
    uint64_t serial=0;
    double chance=0,speed=0,life=0,base_damage=0,base_attack=0,base_knock=0,base_life=0,projectile_increment=0,duration_increment=0,knockback_increment=0,area_increment=0;
    std::vector<KnockbackVisual> visuals;
};
struct FlashSlashMark {EnemyHandle target;int64_t id=0,dash=0;double distance=0,damage=0,time=-1,delay=0,age=0;uint32_t left=0,total=0;};
struct FlashSlashState {bool ready=false;uint32_t definition=0,cuts=0,streaks=0;double multiplier=0,pause=0,sweep=0,clock=0,released=-1;std::vector<FlashSlashMark> marks;std::unordered_map<int64_t,std::unordered_set<int64_t>> marked_ids;};
struct AfterimageLeg {godot::Vector2 a,b;double start=0,finish=0,power=0,radius=0;};
struct AfterimageCopy {godot::Vector2 pos,dir;double delay=0,progress=0,alpha=0;size_t cursor=0;std::unordered_set<int64_t> hits;};
struct AfterimageEcho {uint64_t id=0;double start=0,until=0,share=0;bool ended=false;std::vector<AfterimageLeg> legs;std::vector<AfterimageCopy> copies;};
struct AfterimageState {bool ready=false;uint32_t definition=0,count=0;uint64_t next_id=1,current=0;double clock=0,total=0,delay=0;std::vector<AfterimageEcho> echoes;};
struct EscortTrailPoint {godot::Vector2 pos;double life=0.22;bool join=false;};
struct EscortDrone {godot::Vector2 pos,dir;std::vector<EscortTrailPoint> trail;bool break_trail=true;};
struct DashRangeDroneState {bool ready=false,active=false;uint32_t definition=0,count=0;int64_t dash_id=-1;double distance=0,damage=0,tail=0,hit_radius=0,area_increment=0,deploy_distance=0,idle_spacing=0,idle_back=0,return_rate=0;std::vector<EscortDrone> drones;std::vector<godot::Vector2> normals;std::unordered_set<int64_t> hits;};
struct InterceptorDrone {godot::Vector2 pos;EnemyHandle target;int64_t target_id=-1;double angle=0,flash=0,kick=0,next=0;uint32_t left=0;};
struct InterceptorState {bool ready=false;uint32_t definition=0,count=0,burst=0,color=0;double clock=0,damage=0,interval=0,burst_interval=0,range=0,orbit=0,orbit_speed=0,target_interval=0,shot_radius=0,shot_speed=0,life=0,projectile_increment=0,duration_increment=0,interval_increment=0,minimum_ratio=0,minimum_interval=0;std::vector<InterceptorDrone> drones;std::unordered_map<int64_t,double> target_after;};
struct BipolarPending {godot::Vector2 from,to;uint64_t id=0;double delay=0;};
struct BipolarBeam {godot::Vector2 from,to;uint64_t id=0;double age=0,width_scale=1;};
struct BipolarState {bool ready=false,active=false;uint32_t definition=0,color=0;godot::Vector2 origin;uint64_t next_id=1;double started=0,damage=0,width=0,radius_factor=1,life=0,knock=0,min_length=0,delay=0,visual_life=0,area_increment=0,knockback_increment=0;std::vector<BipolarPending> pending;std::vector<BipolarBeam> beams;};
struct TowCargo {godot::Vector2 pos,relative;double radius=0,angle=0;uint32_t definition=0;int64_t source_id=0;bool ready=false,twin=false;};
struct MassTowState {bool ready=false;uint32_t definition=0;IntervalTimer fire;double capture_radius=0,hold=0,follow=0,interval=0,shot_speed=0,damage=0,size_ref=1,life=0,knock=0,clump_spacing=0,projectile_increment=0,duration_increment=0,knockback_increment=0,area_increment=0,interval_increment=0,minimum_ratio=0,minimum_interval=0;uint32_t visible=1;std::vector<TowCargo> cargo;};
struct ContactArcVisual {uint64_t id=0;double age=0;std::vector<godot::Vector2> segments;};
struct ContactArcState {bool ready=false;uint32_t definition=0,chains=0,branches=0;double ready_at=0,damage=0,range=0,cooldown=0,knock=0,area_increment=0,knockback_increment=0,visual_life=0;uint64_t next_visual=1;std::vector<ContactArcVisual> visuals;};
struct SonicRing {godot::Vector2 pos;double age=0;bool twin=false;};
struct SonicPending {EnemyHandle target;int64_t id=0;double delay=0,age=0,damage=0;godot::Vector2 velocity;bool hit=false;};
struct SonicVisual {uint64_t id=0;int64_t target=0;godot::Vector2 pos,direction;double born=0;bool impact=false,dead=false;};
struct SonicState {
    bool ready=false,active=false;uint32_t definition=0;uint64_t next_visual=1;
    godot::Vector2 last;double emission=0,distance=0,pulse=0,speed=0,wave_speed=0,life=0;
    double damage=0,base_speed=0,base_life=0,emit_spacing=0,min_speed=0,nose=0,pulse_distance=0,pulse_time=0,side_speed=0,back_speed=0,decay=1,damage_delay=0,area_increment=0,duration_increment=0;
    std::vector<SonicRing> frames;std::vector<SonicPending> pending;std::unordered_set<int64_t> hits;std::vector<SonicVisual> visuals;
};
struct ContactWaveCaught {EnemyHandle target;int64_t id=0;double age=0;};
struct ContactWaveInstance {
    godot::Vector2 pos;uint64_t id=0;double radius=0,damage=0,age=0,visual_age=0;
    std::vector<ContactWaveCaught> caught;std::unordered_set<int64_t> done;
};
struct ContactWaveRipple {godot::Vector2 pos;double radius=0,age=0;};
struct ContactWaveState {
    bool ready=false;uint32_t definition=0;uint64_t next_id=1;
    double radius=0,damage=0,knock=0,area_increment=0,knockback_increment=0;
    std::vector<ContactWaveInstance> waves;
    std::vector<ContactWaveRipple> ripples;
};
struct KillSonicWave {godot::Vector2 pos;uint64_t id=0;int64_t generation=0;double radius=0,damage=0,age=0,born=0,life=0;std::unordered_set<int64_t> hits;};
struct KillSonicState {bool ready=false,active=false;uint32_t definition=0;int64_t every=0,limit=0,chains=0,kills=0,next=0;uint64_t next_id=1;double radius=0,damage=0,radius_decay=0,damage_decay=0,knock=0,life=0;std::vector<KillSonicWave> waves;};
struct CritBeamState {bool ready=false;double next_time=0,cooldown=0,damage=0,length=0,width=0,knock=0;};
struct VortexInstance {
    godot::Vector2 pos;
    uint64_t id=0,kills=0;
    double age=0,radius=0,damage=0,duration=0;
    std::unordered_set<int64_t> hits;
    // ふたご座の影があけた穴（影に付いて動く）
    bool twin=false;
};
struct VortexVisual {
    godot::Vector2 pos;
    godot::Color color;
    uint64_t id=0;
    uint32_t kind=0,definition=0;
    double age=0,life=0,radius=0,facing=0,amount=0;
    // ふたご座の影の穴の見た目（影の位置に描く）
    bool twin=false;
};
struct VortexState {
    bool ready=false;
    uint64_t serial=0;
    double damage=0,radius=0,kills=1,charge=0,hold=0,collapse=0;
    std::vector<VortexInstance> items;
    std::vector<VortexVisual> visuals;
};
struct RunUpHitState {godot::Vector2 pos,direction;double age=0;uint64_t id=0;};
struct RunUpState {
    bool ready=false,first=true;
    double strength=0,distance=1,multiplier=1,radius=0,area_damage=0;
    uint64_t next_visual=1;std::vector<RunUpHitState> hits;
};
struct RampageState {
    bool ready=false;
    uint64_t kills=0;
    double strength=0,pop=0,bonus=0,half_life=1,target_kills=1;
};
struct DuplicatorState {
    bool ready=false;
    double chance=0,damage=1,angle_min=0,angle_max=0;
    uint32_t maximum=0;
};
struct CardCandidate {int64_t id=0;CardKind kind=CardKind::Weapon;uint32_t definition=0,level=0;};
// 数値特性は取得の境界で畳み、武器の更新中には定義を探索しない。
struct EquipmentEffects {
    double area=1,shot_amount=1,full_gauge_rate=0;
    double burst_power=1,damage_multiplier=1;
    bool ignore_armor=false;
};
struct LoadoutState {
    EquipmentEffects effects;
    bool full_burst_owned=false,full_burst_active=false;
    KnockbackState knockback;
    ContactWaveState contact_wave;
    SonicState sonic;
    ContactArcState contact_arc;
    KillSonicState kill_sonic;
    MassTowState mass_tow;
    BipolarState bipolar;
    InterceptorState interceptor;
    // ふたご座の影に付く迎撃ドローン（ドローン・時計・狙い直しの待ちは機ごとに要るので、影がいる間だけ機体の設定を写して使う）
    InterceptorState twin_interceptor;
    DashRangeDroneState escort;
    // ふたご座の影に付くエスコートウィング（編隊・展開・命中の状態は機ごとに要るので、影がいる間だけ機体の設定を写して使う）
    DashRangeDroneState twin_escort;
    AfterimageState afterimage;
    FlashSlashState flash_slash;
    CritBeamState crit_beam;
    VortexState vortex;
    RunUpState run_up;
    RampageState rampage;
    DuplicatorState duplicator;
    double boost_distance=0,full_charge_maximum=1;
    MinesWeaponState mines;
    EndBlastWeaponState end_blast;
    ScatterWeaponState scatter;
    RearWeaponState rear;
    BarrierWeaponState barrier;
    uint64_t post_weapon_interval_stacks=0,post_projectile_speed_stacks=0,post_duration_stacks=0,post_knockback_stacks=0,post_area_stacks=0;

    std::vector<int32_t> meta_levels;
    double hp_profile_add=0,xp_profile_factor=1,reroll_profile_add=0;
    double fuel_gain_profile_factor=1,speed_profile_factor=1,attack_profile_factor=1,pickup_profile_factor=1,length_profile_factor=1;
    uint64_t post_charge_stacks=0,post_crit_stacks=0,post_max_speed_stacks=0,post_weapon_damage_stacks=0,post_followup_stacks=0,post_xp_pickup_stacks=0,post_line_length_stacks=0;
    uint64_t post_max_hp_stacks=0,post_crit_mult_stacks=0,post_acceleration_stacks=0,post_turn_rate_stacks=0,post_invulnerability_stacks=0,post_repair_stacks=0,post_pickup_speed_stacks=0,post_xp_gain_stacks=0;
    double post_hp_applied=0;
    std::vector<double> weapon_damage_factors;
    bool ready=false,initial_offer=false;
    int64_t level=0,pending_levels=0,rerolls=0,next_offer_id=1,offer_id=0,selected_id=0;
    double xp=0,xp_gained=0,xp_gain_mult=1;
    std::vector<EquipmentLevel> weapons,traits;
    uint32_t comet_weapon=0;
    bool comet_direct=false;
    std::vector<uint32_t> pending_comet_weapons;
    std::vector<CardCandidate> candidates;
};
}
