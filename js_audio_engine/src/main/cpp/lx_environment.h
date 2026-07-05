#ifndef LX_ENVIRONMENT_H
#define LX_ENVIRONMENT_H

#include <string>
#include <map>

namespace JsAudioEngine {

/**
 * LxEnvironment - DEPRECATED with the new JSVM engine.
 * The globalThis.lx object is now built entirely by the preload script
 * (user-api-preload.js) evaluated inside the JSVM.
 *
 * This class is kept for compatibility with the existing build structure.
 */
class LxEnvironment {
public:
    LxEnvironment() = default;
    ~LxEnvironment() = default;

    void Inject() {}
};

} // namespace JsAudioEngine

#endif // LX_ENVIRONMENT_H
