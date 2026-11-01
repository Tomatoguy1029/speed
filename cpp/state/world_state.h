#pragma once
#include "entity_store.h"
#include "../content/generated/combat_ids.h"
#include <godot_cpp/variant/vector2.hpp>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <vector>
namespace speed {
// 挿入順と検索索引を分ける。消去は残りの順を保ち、コピーに生参照を持ち込まない。
template<class Key,class Value> class OrderedValues {
    struct Entry {Key key;Value value;};
    std::vector<Entry> values;
    std::unordered_map<Key,size_t> index;
public:
    auto begin() {return values.begin();}auto end() {return values.end();}
    auto begin() const {return values.begin();}auto end() const {return values.end();}
    bool is_empty() const {return values.empty();}
    size_t size() const {return values.size();}
    Value *getptr(const Key &key) {const auto found=index.find(key);return found==index.end()?nullptr:&values[found->second].value;}
    const Value *getptr(const Key &key) const {const auto found=index.find(key);return found==index.end()?nullptr:&values[found->second].value;}
    void insert(const Key &key,const Value &value) {if (auto found=getptr(key)) {*found=value;return;}index.emplace(key,values.size());values.push_back({key,value});}
    void erase(const Key &key) {
        const auto found=index.find(key);if (found==index.end()) return;
        const size_t at=found->second;index.erase(found);values.erase(values.begin()+at);
        for (size_t i=at;i<values.size();++i) index[values[i].key]=i;
    }
    Value &operator[](const Key &key) {return values[index.at(key)].value;}
};
struct AttackBudgetState {
    struct Member {EnemyHandle actor;double until=0;bool begun=false,closed=false;};
    struct Group {
        std::string owner;
        uint32_t definition=0;
        EnemyHandle actor;
        int64_t id=0;
        double cost=1,until=0,start=0;
        bool passive=false;
        uint32_t residuals=0;
        godot::Vector2 pos;
        std::vector<AttackCategory> categories;
        OrderedValues<int64_t,Member> members;
        std::unordered_set<std::string> external;
    };
    struct Waiting {
        int64_t id=0;
        EnemyHandle actor;
        double since=0,priority=0,cost=1,ready=0;
        bool has_ready=false;
        std::vector<AttackCategory> categories;
    };
    OrderedValues<int64_t,Group> groups;
    OrderedValues<std::string,int64_t> owners;
    OrderedValues<std::string,Waiting> waiting;
    bool enabled=false,guard=false,frame_enabled=false,stage_budget=false;
    double budget=4,jitter=0.3,now=0,guard_until=-1;
    int64_t serial=0;
};
struct WorldState {
    AttackBudgetState attack_budget;
    bool attack_formation_mode=false;
};
}
