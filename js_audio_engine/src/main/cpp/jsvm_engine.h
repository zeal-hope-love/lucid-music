#ifndef JSVM_ENGINE_H
#define JSVM_ENGINE_H

#include <string>
#include <functional>
#include <mutex>
#include <ark_runtime/jsvm.h>
#include <ark_runtime/jsvm_types.h>

namespace JsAudioEngine {

// Callback from JSVM to ArkTS: (action, jsonData) -> void
using NativeActionCallback = std::function<void(const std::string& action, const std::string& jsonData)>;

/**
 * Core JSVM engine mirroring LX Music Mobile's QuickJS.java.
 *
 * Lifecycle:
 *   CreateEngine() → ExecuteScript(script, id) → [ArkTS handles events] → ReleaseEngine()
 *
 * Architecture (matching LX Music Mobile):
 *   1. Create OH_JSVM runtime + context
 *   2. Inject 7 native functions into global scope:
 *      - __lx_native_call__          (key, action, data) → NAPI callback → ArkTS
 *      - __lx_native_call__utils_str2b64   (str) → base64
 *      - __lx_native_call__utils_b642buf   (b64) → JSON number array
 *      - __lx_native_call__utils_str2md5   (urlEncoded) → md5 hex
 *      - __lx_native_call__utils_aes_encrypt (data,key,iv,mode) → b64
 *      - __lx_native_call__utils_rsa_encrypt (data,key,padding) → b64
 *      - __lx_native_call__set_timeout      (id, ms) → schedule callback
 *   3. Evaluate preload script (user-api-preload.js)
 *   4. Call lx_setup(key, id, name, ...) → assembles globalThis.lx
 *   5. Evaluate user script
 */
class JsvmEngine {
public:
    static JsvmEngine& GetInstance();

    void CreateEngine();

    /**
     * Execute a JavaScript source script.
     * Must call CreateEngine() first.
     */
    bool ExecuteScript(const std::string& scriptContent, const std::string& scriptId);

    /**
     * Call __lx_native__ from ArkTS side (mirrors QuickJS.java callJS()).
     * Used for: __set_timeout__, request, response
     * @param action  Action name
     * @param data    JSON string data (may be empty)
     */
    std::string JsCall(const std::string& action, const std::string& data);

    void ReleaseEngine();
    bool IsReady() const { return ready_; }

    /** Register callback for native-to-ArkTS communication */
    void SetActionCallback(NativeActionCallback cb);

private:
    JsvmEngine() = default;
    ~JsvmEngine();
    JsvmEngine(const JsvmEngine&) = delete;
    JsvmEngine& operator=(const JsvmEngine&) = delete;

    // ---- Engine lifecycle ----
    void InitJSVM();
    void InjectNativeFunctions();
    bool EvaluatePreloadScript(const std::string& scriptId);
    bool EvaluateUserScript(const std::string& scriptContent, const std::string& scriptId);

    // ---- Native function callbacks (registered into JS global scope) ----
    static JSVM_Value NativeCallCb(JSVM_Env env, JSVM_CallbackInfo info);
    static JSVM_Value UtilsStr2B64Cb(JSVM_Env env, JSVM_CallbackInfo info);
    static JSVM_Value UtilsB642BufCb(JSVM_Env env, JSVM_CallbackInfo info);
    static JSVM_Value UtilsStr2Md5Cb(JSVM_Env env, JSVM_CallbackInfo info);
    static JSVM_Value UtilsAesEncryptCb(JSVM_Env env, JSVM_CallbackInfo info);
    static JSVM_Value UtilsRsaEncryptCb(JSVM_Env env, JSVM_CallbackInfo info);
    static JSVM_Value SetTimeoutCb(JSVM_Env env, JSVM_CallbackInfo info);

    // ---- Helpers ----
    static std::string JsvmValueToString(JSVM_Env env, JSVM_Value value);
    static std::string GetArgString(JSVM_Env env, JSVM_CallbackInfo info, int index);
    static int GetArgInt(JSVM_Env env, JSVM_CallbackInfo info, int index, int defaultVal = 0);

    // ---- State ----
    bool ready_ = false;
    bool jsvmGlobalInited_ = false;           // OH_JSVM_Init should only be called once globally
    JSVM_Env jsEnv_ = nullptr;
    JSVM_VM jsVM_ = nullptr;
    JSVM_EnvScope envScope_ = nullptr;  // EnvScope must stay alive for script execution
    std::string currentScriptId_;
    std::string randomKey_;                    // random key matching LX Mobile's UUID approach
    NativeActionCallback actionCallback_;
    mutable std::recursive_mutex mutex_;

    // Preload script (embedded from user-api-preload.js)
    static const char* PRELOAD_SCRIPT;
};

} // namespace JsAudioEngine

#endif // JSVM_ENGINE_H
