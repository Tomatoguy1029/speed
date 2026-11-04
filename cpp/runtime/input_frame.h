#pragma once
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <cmath>
namespace speed {
struct InputFrame {
    bool has_cursor=false,stick_active=false,press=false,alt_press=false,hero_press=false,pen_release=false,touch=false;
    bool finale_pressed=false,finale_released=false;
    godot::Vector2 cursor,stick,pen,finale_pen;
};
inline bool decode_input(const godot::Dictionary &data,InputFrame &out,bool strict=true) {
    const char *flags[]={"has_cursor","stick_active","press","alt_press","hero_press","pen_release","touch","finale_pressed","finale_released"};
    bool *values[]={&out.has_cursor,&out.stick_active,&out.press,&out.alt_press,&out.hero_press,&out.pen_release,&out.touch,&out.finale_pressed,&out.finale_released};
    const char *vectors[]={"cursor","stick","pen","finale_pen"};
    godot::Vector2 *positions[]={&out.cursor,&out.stick,&out.pen,&out.finale_pen};
    if (strict && data.size()!=13) return false;
    for (unsigned i=0;i<9;++i) {
        if (!data.has(flags[i])) {if (strict) return false;continue;}
        if (data[flags[i]].get_type()!=godot::Variant::BOOL) return false;
        *values[i]=data[flags[i]];
    }
    for (unsigned i=0;i<4;++i) {
        if (!data.has(vectors[i])) {if (strict) return false;continue;}
        if (data[vectors[i]].get_type()!=godot::Variant::VECTOR2 || !godot::Vector2(data[vectors[i]]).is_finite()) return false;
        *positions[i]=data[vectors[i]];
    }
    return true;
}
}
