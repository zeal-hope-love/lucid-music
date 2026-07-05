#include "lx_event_bus.h"
#include <hilog/log.h>

namespace JsAudioEngine {

LxEventBus& LxEventBus::GetInstance() {
    static LxEventBus instance;
    return instance;
}

void LxEventBus::On(const std::string& eventName, EventHandler handler) {
    std::lock_guard<std::mutex> lock(mutex_);
    handlers_[eventName].push_back(handler);
}

void LxEventBus::Send(const std::string& eventName, const std::string& data) {
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = handlers_.find(eventName);
    if (it != handlers_.end()) {
        for (auto& handler : it->second) {
            handler(data);
        }
    }
}

void LxEventBus::RemoveListener(const std::string& eventName) {
    std::lock_guard<std::mutex> lock(mutex_);
    handlers_.erase(eventName);
}

} // namespace JsAudioEngine
