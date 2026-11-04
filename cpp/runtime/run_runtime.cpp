#include "run_runtime.h"
#include "../content/content_bundle.h"
namespace speed {
RunRuntime::RunRuntime(): content(std::make_shared<const ContentBundle>()) {}
RunRuntime::~RunRuntime()=default;
void RunRuntime::replace_definitions(std::vector<EnemyDefinition> definitions) {
    auto next=std::make_shared<ContentBundle>();
    next->definitions=std::move(definitions);
    content=std::move(next);
}
}
