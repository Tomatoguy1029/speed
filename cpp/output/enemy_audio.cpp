#include "enemy_audio.h"
#include "event_builder.h"
#include "../runtime/run_runtime.h"
#include "../content/content_bundle.h"
namespace speed {
namespace {
using Kind=EnemyDefinition::Kind;
/// 種類と、入った段階 → 欄。ループする欄は loop を立て、その段階を出たら止める。
struct ModeSound {Kind kind;EnemyMode mode;const char *cue;bool loop=false;};
constexpr ModeSound MODE_SOUNDS[]={
    {Kind::Dash,EnemyMode::Windup,"enemy.charger.tell"},{Kind::Dash,EnemyMode::Dash,"enemy.charger.dash"},
    {Kind::Bomber,EnemyMode::Windup,"enemy.bomber.ignite"},
    {Kind::Pulser,EnemyMode::Windup,"enemy.pulser.charge"},
    {Kind::Aquila,EnemyMode::Windup,"elite.aquila.aim"},{Kind::Aquila,EnemyMode::Dash,"elite.aquila.dive"},
    {Kind::Crab,EnemyMode::Move,"elite.crab.walk",true},{Kind::Crab,EnemyMode::Recover,"elite.crab.attack"},
    {Kind::Dolphin,EnemyMode::Windup,"elite.dolphin.stance"},{Kind::Dolphin,EnemyMode::Recover,"elite.dolphin.wave"},
    {Kind::Marlin,EnemyMode::Windup,"elite.marlin.stop"},{Kind::Marlin,EnemyMode::Dash,"elite.marlin.dash"},
    {Kind::Phoenix,EnemyMode::Windup,"elite.phoenix.tell"},{Kind::Phoenix,EnemyMode::Dash,"elite.phoenix.dive"},
    {Kind::Pump,EnemyMode::Move,"elite.pump.suck",true},{Kind::Pump,EnemyMode::Recover,"elite.pump.fire"},
    {Kind::Cross,EnemyMode::Windup,"elite.cross.charge"},{Kind::Cross,EnemyMode::Recover,"elite.cross.fire"},
    {Kind::Reticle,EnemyMode::Windup,"elite.reticle.tell"},
    {Kind::Ruler,EnemyMode::Recover,"elite.ruler.line"},
};
/// 現れた時に鳴らす欄。loop の欄は、いる間ずっと鳴らす。
struct LifeSound {Kind kind;const char *cue;bool loop;};
constexpr LifeSound LIFE_SOUNDS[]={{Kind::TriangleStar,"elite.triangle.spin",true},{Kind::Auriga,"elite.auriga.drive",true},
    {Kind::Hound,"enemy.hound.rush",false},{Kind::Defender,"enemy.defender.line",false}};
}
void EnemyAudio::mode_changed(RunRuntime &run,uint32_t row,EnemyMode before) {
    const auto &e=run.state.enemies[row];if (e.mode==before) return;const auto kind=run.content->definitions[e.definition].kind;
    for (const auto &s:MODE_SOUNDS) {
        if (s.kind!=kind) continue;
        if (s.mode==before && s.loop) EventBuilder::audio_loop(run,s.cue,e.id,false);
        if (s.mode!=e.mode) continue;
        if (s.loop) EventBuilder::audio_loop(run,s.cue,e.id,true);
        else EventBuilder::audio(run,s.cue,e.pos);
    }
    // パルサーは溜めから戻る時に撃つ。フェニックスは飛び込みの後で飛び去る。
    if (kind==Kind::Pulser && before==EnemyMode::Windup && e.mode==EnemyMode::Move) EventBuilder::audio(run,"enemy.pulser.fire",e.pos);
    if (kind==Kind::Phoenix && before==EnemyMode::Recover && e.mode==EnemyMode::Move) EventBuilder::audio(run,"elite.phoenix.leave",e.pos);
}
void EnemyAudio::spawned(RunRuntime &run,uint32_t row) {
    const auto &e=run.state.enemies[row];const auto kind=run.content->definitions[e.definition].kind;
    for (const auto &s:MODE_SOUNDS) if (s.kind==kind && s.loop && s.mode==e.mode) EventBuilder::audio_loop(run,s.cue,e.id,true);
    for (const auto &s:LIFE_SOUNDS) {
        if (s.kind!=kind) continue;
        if (s.loop) EventBuilder::audio_loop(run,s.cue,e.id,true);else EventBuilder::audio(run,s.cue,e.pos);
    }
}
}
