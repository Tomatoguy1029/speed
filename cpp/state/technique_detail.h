#pragma once
#include <cstdlib>
#include <type_traits>
#include <utility>
namespace speed {
// 技ごとの状態を、定義を読まずに保持する。使う側のファイルだけが型を知る。
class TechniqueDetail {
    // 書き換え可能な領域にして、最適化で別の型の目印へ統合されないようにする。
    template<class T> struct Tag {static inline char mark=0;};
    using Copy=void *(*)(const void *);
    using Destroy=void (*)(void *);
    void *value=nullptr;
    const void *tag=nullptr;
    Copy copy=nullptr;
    Destroy destroy=nullptr;
    void clear() {if (value) destroy(value);value=nullptr;tag=nullptr;}
    void take(TechniqueDetail &other) {
        value=other.value;tag=other.tag;copy=other.copy;destroy=other.destroy;
        other.value=nullptr;other.tag=nullptr;
    }
public:
    TechniqueDetail()=default;
    TechniqueDetail(const TechniqueDetail &other): value(other.value?other.copy(other.value):nullptr),tag(other.tag),copy(other.copy),destroy(other.destroy) {}
    TechniqueDetail(TechniqueDetail &&other) noexcept {take(other);}
    TechniqueDetail &operator=(const TechniqueDetail &other) {if (this!=&other) {TechniqueDetail held(other);clear();take(held);}return *this;}
    TechniqueDetail &operator=(TechniqueDetail &&other) noexcept {if (this!=&other) {clear();take(other);}return *this;}
    ~TechniqueDetail() {clear();}
    template<class T,class=std::enable_if_t<!std::is_same_v<std::decay_t<T>,TechniqueDetail>>> TechniqueDetail &operator=(T &&next) {
        using Value=std::decay_t<T>;
        Value *held=new Value(std::forward<T>(next));
        clear();
        value=held;tag=&Tag<Value>::mark;
        copy=[](const void *source)->void * {return new Value(*static_cast<const Value *>(source));};
        destroy=[](void *source) {delete static_cast<Value *>(source);};
        return *this;
    }
    bool empty() const {return value==nullptr;}
    template<class T> bool holds() const {return tag==&Tag<T>::mark;}
    template<class T> T *get_if() {return holds<T>()?static_cast<T *>(value):nullptr;}
    template<class T> const T *get_if() const {return holds<T>()?static_cast<const T *>(value):nullptr;}
    template<class T> T &get() {if (!holds<T>()) std::abort();return *static_cast<T *>(value);}
    template<class T> const T &get() const {if (!holds<T>()) std::abort();return *static_cast<const T *>(value);}
};
}
