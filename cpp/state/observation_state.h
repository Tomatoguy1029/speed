#pragma once
#include "entity_store.h"
#include "attack_state.h"
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string_name.hpp>
#include <vector>
#include <algorithm>
#include <cstdint>
namespace speed {
struct ActionObservation {
    int64_t id=0,actor_id=0,decision_id=0;uint32_t definition=0;
    godot::StringName origin="external_forced",reason="finished";
    godot::Dictionary boundary;
    int stage=-1;uint32_t pass=0,warning_pass=0;bool aim_locked=false;
    uint64_t checks=0,contacts=0,attacks=0;
    double applied=0;
    bool executed=false,observed_start=true,running=true;
};
struct ObservationEvent {ActionObservation action;enum Step {Selected,Execute,Warning,AimLock,Recovery,Interrupted,Finished,RecordingEnd,ActorEnd} step=Selected;};
struct EffectObservation {
    int64_t id=0,observation_id=0,actor_id=0;uint32_t definition=0;
    godot::Vector2 born_pos,pos;uint64_t checks=0,contacts=0;double applied=0;
    bool observed_start=true;ActionObservation action;
};
struct EffectObservationEvent {
    EffectObservation effect;enum Step {Spawned,Ended,RecordingEnd} step=Spawned;
    AttackEndReason reason=AttackEndReason::Lifetime;
};
// 行動と発生攻撃が同じ値IDを保持する。終了済みの行動も残留攻撃の間は保持する。
struct ObservationState {
    bool recording=false;uint32_t detail_level=2;int64_t next_id=1;
    uint64_t effect_tracking_dropped=0;
    std::vector<EffectObservation> effects;
    std::vector<EffectObservationEvent> pending_effects;
    std::vector<ActionObservation> actions;
    std::vector<ObservationEvent> pending;
    ActionObservation *find(int64_t id) {for (auto &a:actions) if (a.id==id) return &a;return nullptr;}
    int64_t begin(int64_t actor,uint32_t definition,bool observed=true,const char *origin="external_forced",int64_t decision_id=0) {
        if (!recording || !detail_level || next_id==INT64_MAX) return 0;
        ActionObservation a;a.id=next_id++;a.actor_id=actor;a.definition=definition;a.observed_start=observed;a.origin=observed?origin:"unobserved";a.decision_id=decision_id;
        actions.push_back(a);pending.push_back({a,ObservationEvent::Selected});return a.id;
    }
    void execute(int64_t id) {if (auto *a=find(id);a && !a->executed) {a->executed=true;pending.push_back({*a,ObservationEvent::Execute});}}
    bool check(int64_t id,bool touching) {execute(id);if (auto *a=find(id)) {++a->checks;if (touching) ++a->contacts;}return touching;}
    void retain(int64_t id) {if (auto *a=find(id)) {++a->attacks;execute(id);}}
    void close(int64_t id,ObservationEvent::Step step=ObservationEvent::Finished) {
        for (auto it=actions.begin();it!=actions.end();++it) if (it->id==id) {pending.push_back({*it,step});actions.erase(it);return;}
    }
    void release(int64_t id) {if (auto *a=find(id)) {if (a->attacks) --a->attacks;if (!a->running && !a->attacks) close(id);}}
    void finish(int64_t id) {if (auto *a=find(id)) {a->running=false;if (!a->attacks) close(id);}}
    void actor_ended(int64_t actor) {for (size_t i=actions.size();i>0;--i) if (actions[i-1].actor_id==actor) close(actions[i-1].id,ObservationEvent::ActorEnd);}
    EffectObservation *find_effect(int64_t id) {for (auto &e:effects) if (e.id==id) return &e;return nullptr;}
    void effect_begin(int64_t id,int64_t action_id,godot::Vector2 pos,bool observed=true) {
        auto *a=find(action_id);if (!recording || !detail_level || !a || find_effect(id)) return;
        if (effects.size()>=512) {++effect_tracking_dropped;return;}
        EffectObservation e;e.id=id;e.observation_id=action_id;e.actor_id=a->actor_id;e.definition=a->definition;e.born_pos=e.pos=pos;e.observed_start=observed;e.action=*a;
        effects.push_back(e);pending_effects.push_back({e,EffectObservationEvent::Spawned});
    }
    void effect_check(int64_t id,bool touching) {if (auto *e=find_effect(id)) {++e->checks;if (touching) ++e->contacts;}}
    void effect_contact(int64_t id) {if (auto *e=find_effect(id)) ++e->contacts;}
    void effect_damage(int64_t id,double applied) {if (auto *e=find_effect(id)) e->applied+=std::max(0.0,applied);}
    void effect_position(int64_t id,godot::Vector2 pos) {if (auto *e=find_effect(id)) e->pos=pos;}
    void effect_end(int64_t id,godot::Vector2 pos,AttackEndReason reason) {
        for (auto it=effects.begin();it!=effects.end();++it) if (it->id==id) {it->pos=pos;pending_effects.push_back({*it,EffectObservationEvent::Ended,reason});effects.erase(it);return;}
    }
    void stop() {
        for (const auto &e:effects) pending_effects.push_back({e,EffectObservationEvent::RecordingEnd});effects.clear();
        while (!actions.empty()) close(actions.back().id,ObservationEvent::RecordingEnd);recording=false;
    }
};
}
