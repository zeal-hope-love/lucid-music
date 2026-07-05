#ifndef LX_EVENT_BUS_H
#define LX_EVENT_BUS_H

#include "types.h"
#include <map>
#include <vector>
#include <mutex>

namespace JsAudioEngine {

/**
 * Simple event bus for lx.on / lx.send pattern.
 */
class LxEventBus {
public:
    static LxEventBus& GetInstance();

    void On(const std::string& eventName, EventHandler handler);
    void Send(const std::string& eventName, const std::string& data);
    void RemoveListener(const std::string& eventName);

private:
    LxEventBus() = default;
    std::map<std::string, std::vector<EventHandler>> handlers_;
    std::mutex mutex_;
};

} // namespace JsAudioEngine

#endif // LX_EVENT_BUS_H
