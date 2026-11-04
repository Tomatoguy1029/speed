#include "leo.h"
#include "../../runtime/run_runtime.h"
#include "../../content/content_bundle.h"
namespace speed {
double LeoBehavior::trace_width(const RunRuntime &run) {
    const auto &h=run.state.heroes;if (h.active<=0) return 1;
    for (const auto &d:run.content->leo) if (d.hero==h.power) return d.width_mult;
    return 1;
}
}
