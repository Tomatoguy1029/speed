#include "sweep_visual.h"
#include "../../state/boss_states.h"
#include <algorithm>
#include <cmath>
namespace speed {
namespace {
// PX.Rng の uint32 乗算をそのまま使い、spawnで消費するseedも進める。
double next(uint32_t &state) {
    uint32_t t=(state+=0x6d2b79f5u);
    t=(t^(t>>15))*(t|1u);
    t^=t+((t^(t>>7))*(t|61u));
    return double(t^(t>>14))/4294967296.0;
}
double range(uint32_t &r,double a,double b) {return a+(b-a)*next(r);}
void emit(MonocerosSweepVisual &v) {
    if (v.points.empty()) return;
    for (int i=0;i<16;++i) {
        const auto index=std::min(v.points.size()-1,size_t(std::floor(range(v.random,0.3,1.0)*(v.points.size()-1)+0.5)));
        const auto &point=v.points[index];const auto outward=(point.tip-point.center).normalized();
        const double speed=range(v.random,30,100)*3.5;
        MonocerosSweepMote p;p.position=point.tip;p.velocity=outward*speed-godot::Vector2(0,35);p.life=p.maximum=range(v.random,0.25,0.55);
        p.color=uint32_t(std::floor(range(v.random,3,5)));next(v.random);
        v.motes.push_back(p);
    }
}
}
void MonocerosSweepVisualSystem::step(RunRuntime &r,BossBodyState &body,const TechniqueState *t,godot::Vector2 center,godot::Vector2 tip) {
    const MonocerosSweepState *s=t?std::get_if<MonocerosSweepState>(&t->detail):nullptr;
    const BossTechniqueDefinition *definition=t && t->definition && t->definition<=r.content->boss_techniques.size()?&r.content->boss_techniques[t->definition-1]:nullptr;
    if (s && definition && s->stage==MonocerosSweepState::Stage::Swing &&
        std::none_of(body.monoceros_sweeps.begin(),body.monoceros_sweeps.end(),[&](const auto &v){return v.technique_id==t->id;})) {
        MonocerosSweepVisual v;v.technique_id=t->id;v.started=v.last_clock=body.clock;v.start_angle=v.last_angle=s->angle;v.arc=definition->arc;v.duration=definition->active;v.side=s->side;
        body.monoceros_sweeps.push_back(std::move(v));
    }
    for (auto &v:body.monoceros_sweeps) {
        const double dt=std::max(0.0,body.clock-v.last_clock);
        if (dt>0) {
            for (auto &m:v.motes) {m.life-=dt;if (m.life<=0) continue;m.velocity-=m.velocity*(0.6*dt);m.position+=m.velocity*dt;}
            v.motes.erase(std::remove_if(v.motes.begin(),v.motes.end(),[](const auto &m){return m.life<=0;}),v.motes.end());
            v.last_clock=body.clock;
        }
        if (v.finished || (!v.points.empty() && dt<=0)) continue;
        const bool current=s && t && t->id==v.technique_id;
        const double angle=current?s->angle:v.last_angle;v.last_angle=angle;
        const double progress=v.arc!=0?std::clamp((angle-v.start_angle)*v.side/v.arc,0.0,1.0):0;
        v.points.push_back({center,tip,progress,body.clock-v.started});
        if (!current || s->stage!=MonocerosSweepState::Stage::Swing) {v.finished=true;emit(v);}
    }
    const double timing=r.content->config.fx_monoceros_sweep_timing;
    body.monoceros_sweeps.erase(std::remove_if(body.monoceros_sweeps.begin(),body.monoceros_sweeps.end(),[&](const auto &v){return v.finished && body.clock-v.started>v.duration+std::max(0.32*timing,0.55);}),body.monoceros_sweeps.end());
}
}
