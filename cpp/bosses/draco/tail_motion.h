#pragma once
#include <functional>
#include <vector>
#include <godot_cpp/variant/vector2.hpp>
namespace speed {
struct DracoTailTiming {double warn=0,active=0,recover=0;};
// 体の節の長さを保ったまま、頭から尾へ向きの変化を足して全身の形を作る。
class DracoTailMotion {public:
    static double soft(double);
    static double smooth(double,double,double);
    static double wind(double,double);
    static std::vector<godot::Vector2> wave(const std::vector<godot::Vector2> &,double,godot::Vector2,double,double,const std::function<double(double)> &);
    static std::vector<godot::Vector2> sweep(const std::vector<godot::Vector2> &,double,godot::Vector2,double,const DracoTailTiming &,double,double *facing);
    static std::vector<godot::Vector2> slam(const std::vector<godot::Vector2> &,double,godot::Vector2,double,double,const DracoTailTiming &,double,double *facing);
    static double strike_time(const DracoTailTiming &t) {return t.active*0.65;}
};}
