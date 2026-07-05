#ifndef LX_HTTP_BRIDGE_H
#define LX_HTTP_BRIDGE_H

#include "types.h"
#include <functional>

namespace JsAudioEngine {

/**
 * LxHttpBridge - DEPRECATED with the new JSVM engine.
 * HTTP requests from the JS script now go through:
 *   __lx_native_call__ → ArkTS callback → @kit.NetworkKit → sendToJs → script callback
 *
 * This class is kept for compatibility with the build structure.
 */
class LxHttpBridge {
public:
    static LxHttpBridge& GetInstance();

    using RequestHandler = std::function<void(const std::string& url, const HttpOptions& options, HttpRequestCallback callback)>;
    void SetRequestHandler(RequestHandler handler);

private:
    LxHttpBridge() = default;
    RequestHandler customHandler_ = nullptr;
};

} // namespace JsAudioEngine

#endif // LX_HTTP_BRIDGE_H
