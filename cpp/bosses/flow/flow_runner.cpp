#include "flow_runner.h"
#include "../hydra/normal_attack.h"
#include "../hydra/squad.h"
#include "technique_runner.h"
#include "phase_controller.h"
#include "../monoceros/charge.h"
#include "../../systems/motion_math.h"
#include "../../systems/attack_budget.h"
#include <algorithm>
#include <cmath>
#include <functional>
#include <map>
#include <set>
namespace speed {
namespace {
EnemyHandle participant(const BossFlowState &f,uint32_t role) {return role<f.participants.size()?f.participants[role]:EnemyHandle();}
bool actor_busy(const RunRuntime &r,EnemyHandle actor) {for (const auto &t:r.state.bosses.techniques) if (same_handle(t.actor,actor) && t.stage<TechniqueStage::Finished) return true;return false;}
uint32_t phase_technique(const RunRuntime &r,const BossFlowState &f,uint32_t id) {
    if (!id || id>r.content->boss_techniques.size()) return 0;const auto &base=r.content->boss_techniques[id-1];
    for (const auto &p:r.content->boss_techniques) if (p.boss==base.boss && p.external_id==base.external_id && p.phase==f.phase) return p.id;
    return 0;
}
bool cooldown_ready(const RunRuntime &r,const BossFlowState &f,const BossFlowNode &node) {
    const uint64_t key=uint64_t(node.participant)<<32|node.technique;const auto actor=participant(f,node.participant);const auto definition=phase_technique(r,f,node.technique);if (!definition) return false;
    if (r.content->bosses[r.content->boss_techniques[definition-1].boss-1].kind==2) {const auto used=f.cooldown_started.find(key);const auto *body=PhaseController::find(r,actor);return used==f.cooldown_started.end() || (body && body->clock>=used->second+TechniqueRunner::cooldown(r,actor,definition));}
    const auto cool=f.cooldowns.find(key);return cool==f.cooldowns.end() || f.clock>=cool->second;
}
std::vector<uint32_t> children(const ContentBundle &c,uint32_t parent) {std::vector<uint32_t> out;for (const auto &p:c.flow_children) if (p.parent==parent) out.push_back(p.child);return out;}
std::vector<uint32_t> sections(const ContentBundle &c,uint32_t flow) {std::vector<uint32_t> out;for (const auto &p:c.flow_sections) if (p.flow==flow) out.push_back(p.id);return out;}
bool filtered_target(const ContentBundle &c,const BossFlowNode &node) {
    if (node.kind!=1) return true;const auto &t=c.boss_techniques[node.technique-1];
    return c.bosses[t.boss-1].kind==2 || (c.bosses[t.boss-1].kind==1 && t.external_id!="rear_attack" && t.external_id!="stomp");
}
bool available(const RunRuntime &r,const BossFlowState &f,uint32_t id,unsigned depth=0) {
    if (!id || id>r.content->flow_nodes.size() || depth>24) return false;const auto &p=r.content->flow_nodes[id-1];const auto list=children(*r.content,id);
    if (p.kind==0) return true;
    if (p.kind==1) {
        const auto actor=participant(f,p.participant);
        if (!depth && p.technique && HydraNormalAttack::supports(r.content->boss_techniques[p.technique-1].kind)) {auto &runtime=const_cast<RunRuntime &>(r);auto *b=HydraNormalAttack::body(runtime,actor);if (b && b->hydra.separated) {const auto *n=HydraNormalAttack::neck(*b,actor);if (!n || !n->motion.attack || !n->motion.ready || n->motion.move!=p.technique) return false;}}
        return PhaseController::can_start(r,actor) && !actor_busy(r,actor) && cooldown_ready(r,f,p) && (HydraNormalAttack::supports(r.content->boss_techniques[p.technique-1].kind) || FlowRunner::condition(r,f,p.condition,filtered_target(*r.content,p),p.participant)) && TechniqueRunner::ready(r,actor,phase_technique(r,f,p.technique));
    }
    if (list.empty()) return false;
    if (p.kind==2) return available(r,f,list.front(),depth+1);
    if (p.kind==3) {for (auto child:list) if (!available(r,f,child,depth+1)) return false;return true;}
    return list.size()==2 && available(r,f,list[FlowRunner::condition(r,f,p.condition,true,p.participant)?0:1],depth+1);
}
void release_ticket(RunRuntime &r,FlowNodeState &node) {
    if (r.state.bosses.handles.contains(node.ticket)) {auto &t=r.state.bosses.techniques[node.ticket.slot];if (t.ticket_refs) --t.ticket_refs;}node.ticket={};
}
void cancel_node(RunRuntime &r,BossFlowState &f,uint32_t row) {
    if (row>=f.nodes.size()) return;auto &n=f.nodes[row];TechniqueRunner::cancel(r,n.ticket);release_ticket(r,n);
    if (n.child!=UINT32_MAX) cancel_node(r,f,n.child);for (auto child:n.branches) cancel_node(r,f,child);n.status=FlowStatus::Cancelled;
}
uint32_t new_node(BossFlowState &f,uint32_t definition) {const uint32_t row=f.nodes.size();FlowNodeState n;n.definition=definition;f.nodes.push_back(n);return row;}
FlowStatus tick_node(RunRuntime &r,BossFlowState &f,uint32_t row,double dt,bool internal=false) {
    if (f.nodes[row].status!=FlowStatus::Running || dt<=0) return f.nodes[row].status;
    const auto &p=r.content->flow_nodes[f.nodes[row].definition-1];const auto list=children(*r.content,p.id);
    if (p.kind==0) {f.nodes[row].elapsed+=dt;if (f.nodes[row].elapsed>=p.seconds) f.nodes[row].status=FlowStatus::Finished;}
    else if (p.kind==1) {
        auto &n=f.nodes[row];
        if (!n.ticket.generation) {
            const uint32_t technique=phase_technique(r,f,p.technique);
            if (!available(r,f,p.id,internal?1:0)) n.status=FlowStatus::Failed;
            else {
                const auto &rule=r.content->boss_techniques[technique-1];const auto actor=participant(f,p.participant);const auto id=r.state.enemy_handles.entity_id(actor);
                bool admitted=true;if (!HydraNormalAttack::supports(rule.kind) && !r.state.world.attack_formation_mode && r.state.world.attack_budget.enabled) admitted=AttackBudgetSystem(r).request({"boss:"+std::to_string(id),{AttackCategory::Aimed},actor,TechniqueRunner::attack_length(r,actor,technique),1.5,1});
                if (admitted) n.ticket=TechniqueRunner::begin(r,actor,technique);
                if (!r.state.bosses.handles.contains(n.ticket)) n.status=FlowStatus::Failed;
                else {if (auto *b=HydraNormalAttack::body(r,actor)) {if (auto *neck=HydraNormalAttack::neck(*b,actor)) HydraSquad::started(*b,*neck);}++r.state.bosses.techniques[n.ticket.slot].ticket_refs;const uint64_t key=uint64_t(p.participant)<<32|p.technique;if (r.content->bosses[rule.boss-1].kind==2) f.cooldown_started[key]=PhaseController::find(r,actor)->clock;else f.cooldowns[key]=f.clock+rule.cd;}
            }
        } else if (!r.state.bosses.handles.contains(n.ticket)) n.status=FlowStatus::Failed;
        else {const auto stage=r.state.bosses.techniques[n.ticket.slot].stage;if (stage==TechniqueStage::Failed || stage==TechniqueStage::Cancelled) n.status=FlowStatus::Failed;else if (!TechniqueRunner::running(r,n.ticket)) n.status=FlowStatus::Finished;}
        if (n.status!=FlowStatus::Running) release_ticket(r,n);
    } else if (p.kind==2) {
        if (f.nodes[row].cursor>=list.size()) f.nodes[row].status=FlowStatus::Finished;
        else {
            if (f.nodes[row].child==UINT32_MAX) {const auto child=new_node(f,list[f.nodes[row].cursor]);f.nodes[row].child=child;}
            const auto result=tick_node(r,f,f.nodes[row].child,dt,true);
            if (result==FlowStatus::Failed || result==FlowStatus::Cancelled) f.nodes[row].status=FlowStatus::Failed;
            else if (result==FlowStatus::Finished) {++f.nodes[row].cursor;f.nodes[row].child=UINT32_MAX;if (f.nodes[row].cursor>=list.size()) f.nodes[row].status=FlowStatus::Finished;}
        }
    } else if (p.kind==3) {
        if (f.nodes[row].branches.empty()) for (auto definition:list) {const auto child=new_node(f,definition);f.nodes[row].branches.push_back(child);}
        const auto branches=f.nodes[row].branches;uint32_t done=0;
        for (auto child:branches) {const auto result=tick_node(r,f,child,dt,true);if (result==FlowStatus::Failed || result==FlowStatus::Cancelled) {cancel_node(r,f,row);f.nodes[row].status=FlowStatus::Failed;return FlowStatus::Failed;}if (result==FlowStatus::Finished) ++done;}
        if (done==branches.size()) f.nodes[row].status=FlowStatus::Finished;
    } else {
        if (f.nodes[row].child==UINT32_MAX) {const auto child=new_node(f,list[FlowRunner::condition(r,f,p.condition,true,p.participant)?0:1]);f.nodes[row].child=child;}
        f.nodes[row].status=tick_node(r,f,f.nodes[row].child,dt,true);
    }
    return f.nodes[row].status;
}
std::string identity(const ContentBundle &c,const std::vector<uint32_t> &actions) {std::vector<std::string> ids;for (auto id:actions) ids.push_back(c.flow_actions[id-1].external_id);std::sort(ids.begin(),ids.end());std::string out;for (const auto &id:ids) {if (!out.empty()) out+='|';out+=id;}return out;}
uint32_t category(const ContentBundle &c,const std::vector<uint32_t> &actions) {return actions.size()>1?3:actions.empty()?4:c.flow_actions[actions[0]-1].category;}
std::array<double,4> weights(const ContentBundle &c,const BossFlowSection &p,uint32_t previous) {
    std::array<double,4> out{};bool has=false;for (const auto &w:c.flow_weights) if (w.section==p.id && w.previous==int64_t(previous)) has=true;
    for (const auto &w:c.flow_weights) if (w.section==p.id && w.previous==(has?int64_t(previous):-1)) out[w.category]=w.weight;return out;
}
bool compatible(const ContentBundle &c,const BossFlowSection &s,const std::vector<uint32_t> &actions,uint32_t next,double cap) {
    const auto &b=c.flow_actions[next-1];double cost=b.cost;for (auto id:actions) {const auto &a=c.flow_actions[id-1];cost+=a.cost;if (a.exclusive || b.exclusive) return false;const auto &left=c.flow_nodes[a.node-1],&right=c.flow_nodes[b.node-1];if (left.kind==1 && right.kind==1 && HydraNormalAttack::supports(c.boss_techniques[left.technique-1].kind) && HydraNormalAttack::supports(c.boss_techniques[right.technique-1].kind) && left.participant==right.participant) return false;for (const auto &p:c.flow_forbidden) if (p.section==s.id && ((p.left==a.external_id && p.right==b.external_id) || (p.right==a.external_id && p.left==b.external_id))) return false;}return cost<=cap+0.00001;
}
std::vector<uint32_t> choose(RunRuntime &r,const BossFlowState &f,const BossFlowSection &section,const std::vector<uint32_t> &candidates,double cap) {
    const auto &c=*r.content;const auto w=weights(c,section,f.last_category_override>=0?f.last_category_override:category(c,f.last));
    struct Identity {std::string name;std::vector<std::vector<uint32_t>> variants;};struct Group {uint32_t category;std::vector<Identity> identities;};std::vector<Group> groups;
    const auto add=[&](uint32_t kind,std::vector<uint32_t> actions) {auto g=std::find_if(groups.begin(),groups.end(),[&](const auto &g){return g.category==kind;});if (g==groups.end()) {groups.push_back({kind,{}});g=groups.end()-1;}const auto key=identity(c,kind==0 && actions.size()>1?std::vector<uint32_t>{actions.front()}:actions);auto id=std::find_if(g->identities.begin(),g->identities.end(),[&](const auto &p){return p.name==key;});if (id==g->identities.end()) {g->identities.push_back({key,{}});id=g->identities.end()-1;}id->variants.push_back(std::move(actions));};
    std::vector<uint32_t> squad;auto *hydra=HydraNormalAttack::body(r,f.actor);
    if (hydra && hydra->hydra.separated && hydra->hydra.squad.tactic==0 && !hydra->hydra.squad.pair.empty()) {
        for (auto actor:hydra->hydra.squad.pair) {uint32_t found=0;for (auto id:candidates) {const auto &node=c.flow_nodes[c.flow_actions[id-1].node-1];if (node.kind==1 && same_handle(participant(f,node.participant),actor)) {found=id;break;}}if (!found) {squad.clear();break;}squad.push_back(found);}
    }
    for (auto id:candidates) {const auto &node=c.flow_nodes[c.flow_actions[id-1].node-1];const bool normal=node.kind==1 && HydraNormalAttack::supports(c.boss_techniques[node.technique-1].kind);if (hydra && hydra->hydra.separated && hydra->hydra.squad.tactic==0 && !hydra->hydra.squad.pair.empty() && normal) continue;add(c.flow_actions[id-1].category,{id});}
    double squad_cost=0;for (auto id:squad) squad_cost+=c.flow_actions[id-1].cost;if (!squad.empty() && squad_cost<=cap+0.00001) add(0,squad);
    if (!(hydra && hydra->hydra.separated && hydra->hydra.squad.tactic==0) && c.boss_flows[f.definition-1].allow_parallel && w[3]>0) for (size_t i=0;i<candidates.size();++i) if (c.flow_actions[candidates[i]-1].category==0) for (size_t j=i+1;j<candidates.size();++j) if (c.flow_actions[candidates[j]-1].category==0 && compatible(c,section,{candidates[i]},candidates[j],cap)) add(3,{candidates[i],candidates[j]});
    const auto previous=identity(c,f.last_category_override==0 && !f.last.empty()?std::vector<uint32_t>{f.last.front()}:f.last);
    if (section.avoid_repeat && !previous.empty()) {auto alternatives=groups;bool positive=false;for (auto &g:alternatives) {g.identities.erase(std::remove_if(g.identities.begin(),g.identities.end(),[&](const auto &p){return p.name==previous;}),g.identities.end());if (!g.identities.empty() && w[g.category]>0) positive=true;}if (positive) groups=std::move(alternatives);}
    double total=0;for (const auto &g:groups) if (!g.identities.empty()) total+=w[g.category];if (total<=0) return {};
    auto &random=r.state.control.rng;double cursor=random.randf()*total;std::vector<uint32_t> actions;
    for (const auto &g:groups) {if (g.identities.empty()) continue;cursor-=w[g.category];if (cursor>=0) continue;size_t picked=0;
        if (!c.boss_flows[f.definition-1].has_bias) picked=*random.randi_range(0,g.identities.size()-1);
        else {double sum=0;for (const auto &id:g.identities) sum+=(g.category==3?1.0:c.flow_actions[id.variants[0][0]-1].weight);if (sum<=0) return {};double draw=random.randf()*sum;picked=g.identities.size()-1;for (size_t i=0;i<g.identities.size();++i) {draw-=(g.category==3?1.0:c.flow_actions[g.identities[i].variants[0][0]-1].weight);if (draw<0) {picked=i;break;}}}
        const auto &variants=g.identities[picked].variants;actions=variants[*random.randi_range(0,variants.size()-1)];break;
    }
    if (actions.size()>1 && !(hydra && hydra->hydra.separated && hydra->hydra.squad.tactic==0)) {auto remaining=candidates;while (!remaining.empty() && random.randf()<0.5) {const size_t pick=*random.randi_range(0,remaining.size()-1);const auto next=remaining[pick];remaining.erase(remaining.begin()+pick);if (c.flow_actions[next-1].category==0 && compatible(c,section,actions,next,cap)) {auto expanded=actions;expanded.push_back(next);if (!section.avoid_repeat || identity(c,expanded)!=previous) actions=std::move(expanded);}}}
    return actions;
}
void reset_wait(BossFlowState &f) {f.waiting=false;f.no_candidate_elapsed=0;}
void advance(BossFlowState &f,const BossFlowSection &p,bool fallback=false) {f.index=fallback&&p.has_fallback?p.fallback:p.next;f.completed_actions=0;f.section_spent=f.interval=0;reset_wait(f);if (fallback) f.retry=0;}
void rest(BossFlowState &f,const BossFlowProgram &p,uint32_t next) {f.rest_next=next;f.interval=0;reset_wait(f);f.rest_remaining=std::max(0.001,f.stamina<=0.00001?p.empty_rest:p.partial_rest);}
void wait_candidate(BossFlowState &f,const BossFlowSection &p) {if ((!p.has_timeout && p.has_fallback) || (p.has_timeout && p.timeout<=0)) advance(f,p,true);else f.waiting=true;}
bool filter(const ContentBundle &c,const BossFlowSection &section,const BossFlowAction &action) {
    bool group=!section.filter_groups,allowed=!section.filter_allowed;for (const auto &p:c.flow_filters) if (p.section==section.id) {if (p.kind==0 && p.value==action.group) group=true;if (p.kind==1 && p.value==std::string(action.label==0?"normal":action.label==1?"combo":"major")) group=true;if (p.kind==2 && p.value==action.external_id) allowed=true;if (p.kind==3 && p.value==action.external_id) return false;}
    if (!section.filter_groups && ((section.request==1 && action.category!=2) || (section.request==0 && action.category==2))) return false;return group && allowed;
}
void tick_flow(RunRuntime &r,BossFlowState &f,double dt) {
    const auto &c=*r.content;const auto &p=c.boss_flows[f.definition-1];const auto list=sections(c,f.definition);
    if (dt<=0) return;if (f.blocked) {FlowRunner::cancel(r,f);return;}if (!f.selection_enabled) return;
    if (!f.roots.empty()) {uint32_t done=0;for (auto root:f.roots) {const auto result=tick_node(r,f,root,dt);if (result==FlowStatus::Failed || result==FlowStatus::Cancelled) {FlowRunner::cancel(r,f);break;}if (result==FlowStatus::Finished) ++done;}if (done==f.roots.size()) {f.roots.clear();f.nodes.clear();}}
    if (f.rest_remaining>0) {f.rest_remaining=std::max(0.0,f.rest_remaining-dt);if (f.rest_remaining<=0) {f.stamina=p.maximum_stamina;f.index=f.rest_next;}return;}
    const auto &section=c.flow_sections[list[f.index]-1];
    if (f.active) {
        bool hydra_wait=false;auto *hydra=HydraNormalAttack::body(r,f.actor);
        if (hydra) for (auto id:f.last) {const auto &node=c.flow_nodes[c.flow_actions[id-1].node-1];if (node.kind==1 && HydraNormalAttack::supports(c.boss_techniques[node.technique-1].kind)) {const auto *n=HydraNormalAttack::neck(*hydra,participant(f,node.participant));if (n && r.state.enemy_handles.contains(n->actor) && !r.state.enemies[n->actor.slot].dead && (n->normal || n->cd>0)) hydra_wait=true;}}
        if (!f.roots.empty() || hydra_wait || (!hydra && std::any_of(f.participants.begin(),f.participants.end(),[&](auto actor){return actor_busy(r,actor);}))) return;f.active=false;++f.completed_actions;
        if (f.completed_actions>=section.action_count || (section.has_budget && f.section_spent>=section.budget-0.00001)) {advance(f,section);f.interval=f.post_gap;}else {f.interval=f.post_gap+section.action_interval;if (f.interval>0) f.retry=0;}f.post_gap=0;
        if (f.stamina<=0.00001) {const auto &next=c.flow_sections[list[f.index]-1];if (next.request==2) f.index=next.next;rest(f,p,f.index);}return;
    }
    if (section.request==2) {f.completed_actions=0;f.section_spent=f.interval=0;reset_wait(f);rest(f,p,section.next);return;}
    if (f.interval>0) {f.interval=std::max(0.0,f.interval-dt);if (f.interval>0) return;}
    if (f.waiting) {f.no_candidate_elapsed+=dt;if (section.has_timeout && f.no_candidate_elapsed>=section.timeout) {advance(f,section,true);return;}}
    f.retry=std::max(0.0,f.retry-dt);if (f.retry>0) return;f.retry=0.15;
    std::vector<uint32_t> candidates,within;const double cap=std::min(section.cap,p.maximum_stamina),budget=section.has_budget?std::max(0.0,section.budget-f.section_spent):1e300;
    double reserved=0;if (const auto *body=HydraNormalAttack::body(r,f.actor)) if (body->hydra.separated) for (const auto &n:body->hydra.necks) if (r.state.enemy_handles.contains(n.actor) && !r.state.enemies[n.actor.slot].dead) reserved+=n.motion.reserved;
    for (const auto &a:c.flow_actions) if (a.flow==f.definition && filter(c,section,a) && (reserved<=0 || a.cost<=f.stamina-reserved+0.00001 || (c.flow_nodes[a.node-1].kind==1 && HydraNormalAttack::supports(c.boss_techniques[c.flow_nodes[a.node-1].technique-1].kind))) && (c.flow_nodes[a.node-1].kind==1 && HydraNormalAttack::supports(c.boss_techniques[c.flow_nodes[a.node-1].technique-1].kind) || FlowRunner::condition(r,f,a.condition,filtered_target(c,c.flow_nodes[a.node-1]))) && available(r,f,a.node)) {if (a.cost<=cap && a.cost<=budget) {within.push_back(a.id);if (a.cost<=f.stamina) candidates.push_back(a.id);}}
    if (candidates.empty()) {if (!within.empty()) rest(f,p,f.index);else wait_candidate(f,section);return;}
    const auto actions=choose(r,f,section,candidates,std::min({cap,budget,f.stamina}));if (actions.empty()) {wait_candidate(f,section);return;}
    f.nodes.clear();f.roots.clear();for (auto id:actions) {const auto &a=c.flow_actions[id-1];f.roots.push_back(new_node(f,a.node));}
    // コンボは作るだけ。単独技は今のtickで開始する。
    for (size_t i=0;i<actions.size();++i) if (c.flow_nodes[c.flow_actions[actions[i]-1].node-1].kind==1 && tick_node(r,f,f.roots[i],dt)!=FlowStatus::Running) {FlowRunner::cancel(r,f);wait_candidate(f,section);return;}
    f.active=true;f.last=actions;f.last_category_override=-1;if (auto *body=HydraNormalAttack::body(r,f.actor)) if (body->hydra.separated && body->hydra.squad.tactic==0 && actions.size()>1) f.last_category_override=0;f.post_gap=0;for (auto id:actions) {const auto &a=c.flow_actions[id-1];f.stamina=std::max(0.0,f.stamina-a.cost);f.section_spent+=a.cost;if (a.label!=1) f.post_gap=std::max(f.post_gap,a.post_gap);}reset_wait(f);
}
}
bool FlowRunner::condition(const RunRuntime &r,const BossFlowState &f,uint32_t definition,bool filtered,uint32_t role) {
    if (!definition) return true;if (definition>r.content->flow_conditions.size() || !r.state.enemy_handles.contains(participant(f,role))) return false;const auto &p=r.content->flow_conditions[definition-1];const auto &e=r.state.enemies[participant(f,role).slot];const auto relative=((filtered?r.state.enemy_aim:r.state.ship_pos)-e.pos).rotated(-e.facing);
    return f.phase>=p.minimum_phase && relative.length()>=p.minimum && relative.length()<=p.maximum && std::abs(angle_difference(relative.angle()-p.angle))<=p.half_angle+0.00001;
}
void FlowRunner::begin_rest(RunRuntime &r,BossFlowState &f,uint32_t next) {rest(f,r.content->boss_flows[f.definition-1],next);}
bool FlowRunner::start_reactive(RunRuntime &r,BossFlowState &f,EnemyHandle actor,uint32_t definition,double cost) {
    if (f.blocked || f.suspended || !f.selection_enabled || f.rest_remaining>0 || !std::isfinite(cost) || cost<0 || !definition || definition>r.content->boss_techniques.size() || r.content->boss_techniques[definition-1].boss!=r.content->boss_flows[f.definition-1].boss) return false;
    const BossFlowSection *section=nullptr;for (const auto &s:r.content->flow_sections) if (s.flow==f.definition && s.order==f.index) section=&s;
    if (!section || section->request==2 || cost>std::min(f.stamina,section->cap)+0.00001 || (section->has_budget && cost>section->budget-f.section_spent+0.00001) || !TechniqueRunner::ready(r,actor,definition)) return false;
    const auto ticket=TechniqueRunner::begin(r,actor,definition);if (!r.state.bosses.handles.contains(ticket)) return false;
    if (auto *b=HydraNormalAttack::body(r,actor)) if (auto *n=HydraNormalAttack::neck(*b,actor)) HydraSquad::started(*b,*n);
    f.stamina=std::max(0.,f.stamina-cost);f.section_spent+=cost;for (const auto &a:r.content->flow_actions) {const auto &node=r.content->flow_nodes[a.node-1];if (a.flow==f.definition && node.kind==1 && node.technique==definition && same_handle(participant(f,node.participant),actor)) {f.last={a.id};f.last_category_override=-1;break;}}return true;
}
bool FlowRunner::attach(RunRuntime &r,EnemyHandle actor,uint32_t definition,const std::vector<EnemyHandle> &participants) {
    if (!definition || definition>r.content->boss_flows.size() || !r.state.enemy_handles.contains(actor) || r.state.enemies[actor.slot].dead) return false;for (const auto &f:r.state.bosses.flows) if (same_handle(f.actor,actor)) return false;
    for (auto item:participants) if (!r.state.enemy_handles.contains(item) || r.state.enemies[item.slot].dead) return false;
    BossFlowState f;f.definition=definition;f.actor=actor;f.participants=participants.empty()?std::vector<EnemyHandle>{actor}:participants;f.stamina=r.content->boss_flows[definition-1].maximum_stamina;r.state.bosses.flows.push_back(f);return true;
}
void FlowRunner::cancel(RunRuntime &r,BossFlowState &f) {for (auto root:f.roots) cancel_node(r,f,root);f.roots.clear();f.nodes.clear();}
void FlowRunner::step(RunRuntime &r,double dt) {
    std::vector<bool> busy;for (const auto &f:r.state.bosses.flows) busy.push_back(std::any_of(f.participants.begin(),f.participants.end(),[&](auto actor){return actor_busy(r,actor);}));TechniqueRunner::step(r,dt);
    for (size_t i=0;i<r.state.bosses.flows.size();++i) {auto &f=r.state.bosses.flows[i];f.clock+=dt;if (!r.state.enemy_handles.contains(f.actor) || r.state.enemies[f.actor.slot].dead) {cancel(r,f);f.blocked=true;continue;}if (f.blocked) {cancel(r,f);continue;}if (f.suspended) continue;if (busy[i] && r.content->boss_flows[f.definition-1].idle_only) continue;tick_flow(r,f,dt);}
}
bool FlowRunner::validate_content(const ContentBundle &c) {
    const auto sequential=[](const auto &rows) {for (size_t i=0;i<rows.size();++i) if (rows[i].id!=i+1) return false;return true;};
    if (!sequential(c.boss_flows) || !sequential(c.flow_sections) || !sequential(c.flow_conditions) || !sequential(c.flow_nodes) || !sequential(c.flow_children) || !sequential(c.flow_actions)) return false;
    for (const auto &p:c.boss_flows) if (p.maximum_stamina<=0 || sections(c,p.id).empty()) return false;
    for (const auto &p:c.flow_sections) {const auto list=sections(c,p.flow);if (p.order>=list.size() || list[p.order]!=p.id || p.next>=list.size() || (p.has_fallback && p.fallback>=list.size()) || p.cap<=0 || (p.has_budget && p.budget<=0)) return false;}
    for (const auto &p:c.flow_conditions) if (p.minimum>p.maximum || p.half_angle>godot::Math::PI) return false;
    std::function<bool(uint32_t,unsigned,std::set<uint32_t>)> tree=[&](uint32_t id,unsigned depth,std::set<uint32_t> path) {
        if (!id || id>c.flow_nodes.size() || depth>24 || !path.insert(id).second) return false;const auto &p=c.flow_nodes[id-1];const auto list=children(c,id);if (p.kind<=1 && !list.empty()) return false;if (p.kind==4 && (list.size()!=2 || !p.condition)) return false;if ((p.kind==2 || p.kind==3) && list.empty()) return false;
        if (p.condition>c.flow_conditions.size() || (p.kind==1 && (!p.technique || p.technique>c.boss_techniques.size() || c.boss_techniques[p.technique-1].boss!=c.boss_flows[p.flow-1].boss))) return false;
        uint32_t order=0;for (const auto &edge:c.flow_children) if (edge.parent==id) {if (edge.order!=order++ || c.flow_nodes[edge.child-1].flow!=p.flow || !tree(edge.child,depth+1,path)) return false;}return true;
    };
    for (const auto &p:c.flow_nodes) if (!tree(p.id,0,{})) return false;for (const auto &p:c.flow_actions) if (c.flow_nodes[p.node-1].flow!=p.flow) return false;return true;
}
bool FlowRunner::validate(const godot::RunState &s,const ContentBundle &c) {
    for (const auto &f:s.bosses.flows) {
        if (f.last_category_override< -1 || f.last_category_override>3 || !f.definition || f.definition>c.boss_flows.size() || f.index>=sections(c,f.definition).size() || f.rest_next>=sections(c,f.definition).size() || f.phase<1 || f.phase>2 || f.participants.empty()) return false;
        for (double value:{f.clock,f.retry,f.stamina,f.rest_remaining,f.section_spent,f.interval,f.no_candidate_elapsed,f.post_gap}) if (!std::isfinite(value) || value<0) return false;
        for (const auto &used:f.cooldown_started) if (!std::isfinite(used.second) || used.second<0) return false;
        for (auto root:f.roots) if (root>=f.nodes.size()) return false;
        for (const auto &n:f.nodes) if (!n.definition || n.definition>c.flow_nodes.size() || n.status>FlowStatus::Cancelled || !std::isfinite(n.elapsed) || n.elapsed<0 || (n.child!=UINT32_MAX && n.child>=f.nodes.size()) || (n.ticket.generation && !s.bosses.handles.contains(n.ticket))) return false;
    }return true;
}
godot::Array FlowRunner::snapshot(const RunRuntime &r) {
    godot::Array out;for (const auto &f:r.state.bosses.flows) {godot::Dictionary p;godot::PackedInt64Array participants;for (auto actor:f.participants) participants.push_back(r.state.enemy_handles.entity_id(actor));p["participants"]=participants;p["definition"]=f.definition;p["actor"]=r.state.enemy_handles.entity_id(f.actor);p["index"]=f.index;p["active"]=f.active;p["stamina"]=f.stamina;p["rest"]=f.rest_remaining;p["spent"]=f.section_spent;p["completed"]=f.completed_actions;p["interval"]=f.interval;p["waiting"]=f.waiting;p["no_candidate_elapsed"]=f.no_candidate_elapsed;p["clock"]=f.clock;godot::Array history;for (auto id:f.last) history.push_back(godot::String(r.content->flow_actions[id-1].external_id.c_str()));p["last"]=history;godot::Array nodes;for (const auto &n:f.nodes) {godot::Dictionary q;q["definition"]=n.definition;q["status"]=int(n.status);q["cursor"]=n.cursor;q["elapsed"]=n.elapsed;nodes.push_back(q);}p["nodes"]=nodes;out.push_back(p);}return out;
}
}
