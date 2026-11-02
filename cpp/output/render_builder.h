#pragma once
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/rect2.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/packed_int64_array.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <map>
#include <vector>
namespace speed {
class RunRuntime;
struct RenderBatchBuffer {
    struct Instance {int64_t id;godot::Vector2 at;double angle,radius;godot::Color color;int32_t flags;};
    uint32_t visual=0;int32_t layer=0,order=0;
    std::vector<Instance> instances;
    bool biter=false;
    godot::PackedInt32Array modes;
    godot::PackedFloat32Array charges,timers,rests,glows,gunner,beamer,missile,battleship,sniper,dolphin,lynx,soldier,reticle,aquarius,cross,bomber,crab,pump;
    godot::PackedInt64Array ids;godot::PackedFloat32Array transforms;godot::PackedColorArray colors;godot::PackedInt32Array flags;
    void add(int64_t id,godot::Vector2 at,double angle,double radius,godot::Color color,int32_t flag=0) {instances.push_back({id,at,angle,radius,color,flag});}
    godot::Dictionary value();
};
struct RenderWorkspace {std::map<uint32_t,RenderBatchBuffer> batches;};
class RenderBuilder {
public:
    static void capture_previous(RunRuntime &);
    static godot::Dictionary read(const RunRuntime &,godot::Rect2 view,double alpha);
};
}
