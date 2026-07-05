#include "lx_http_bridge.h"

namespace JsAudioEngine {

LxHttpBridge& LxHttpBridge::GetInstance() {
    static LxHttpBridge instance;
    return instance;
}

void LxHttpBridge::SetRequestHandler(RequestHandler handler) {
    customHandler_ = handler;
}

// DEPRECATED: HTTP requests are now handled through the action callback
// in jsvm_engine.cpp → ArkTS AudioEngine.ets → @kit.NetworkKit

} // namespace JsAudioEngine
