#ifndef JS_AUDIO_ENGINE_TYPES_H
#define JS_AUDIO_ENGINE_TYPES_H

#include <string>
#include <functional>
#include <map>
#include <mutex>
#include <napi/native_api.h>

namespace JsAudioEngine {

// HTTP request options (passed from script)
struct HttpOptions {
    std::string method = "GET";
    std::map<std::string, std::string> headers;
    std::string body;
    int timeout = 15000;
};

// Callback type for HTTP requests initiated from script lx.request()
using HttpRequestCallback = std::function<void(int statusCode, const std::string& responseBody)>;

// Event handler type
using EventHandler = std::function<void(const std::string& data)>;

// Action callback from JSVM to ArkTS: (action, data) -> void
// Actions: "init", "request", "showUpdateAlert"
using ActionCallback = std::function<void(const std::string& action, const std::string& data)>;

} // namespace JsAudioEngine

#endif // JS_AUDIO_ENGINE_TYPES_H
