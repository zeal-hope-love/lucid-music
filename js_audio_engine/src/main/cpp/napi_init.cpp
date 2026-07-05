#include "napi/native_api.h"
#include "jsvm_engine.h"
#include <hilog/log.h>
#include <string>

#undef LOG_DOMAIN
#undef LOG_TAG
#define LOG_DOMAIN 0x3200
#define LOG_TAG "JSAUDIO_ENGINE"

// Thread-safe callback reference for persistent ArkTS → C++ communication
static napi_threadsafe_function g_tsfn = nullptr;

// ============ Core Engine Functions ============

// Create JSVM engine
static napi_value CreateEngine(napi_env env, napi_callback_info info) {
    JsAudioEngine::JsvmEngine::GetInstance().CreateEngine();
    napi_value result = nullptr;
    napi_get_undefined(env, &result);
    return result;
}

// Execute a JavaScript source script
static napi_value ExecuteScript(napi_env env, napi_callback_info info) {
    size_t argCount = 2;
    napi_value argValues[2] = {nullptr};
    napi_get_cb_info(env, info, &argCount, argValues, nullptr, nullptr);

    // Get scriptContent (string)
    size_t contentLen = 0;
    napi_get_value_string_utf8(env, argValues[0], nullptr, 0, &contentLen);
    char* content = new char[contentLen + 1];
    napi_get_value_string_utf8(env, argValues[0], content, contentLen + 1, &contentLen);
    std::string scriptContent(content);
    delete[] content;

    // Get scriptId (string)
    size_t idLen = 0;
    napi_get_value_string_utf8(env, argValues[1], nullptr, 0, &idLen);
    char* id = new char[idLen + 1];
    napi_get_value_string_utf8(env, argValues[1], id, idLen + 1, &idLen);
    std::string scriptId(id);
    delete[] id;

    bool success = JsAudioEngine::JsvmEngine::GetInstance().ExecuteScript(scriptContent, scriptId);

    napi_value result = nullptr;
    napi_get_boolean(env, success, &result);
    return result;
}

// Call a function from the executed script (legacy direct call)
static napi_value CallFunction(napi_env env, napi_callback_info info) {
    size_t argCount = 2;
    napi_value argValues[2] = {nullptr};
    napi_get_cb_info(env, info, &argCount, argValues, nullptr, nullptr);

    size_t nameLen = 0;
    napi_get_value_string_utf8(env, argValues[0], nullptr, 0, &nameLen);
    char* name = new char[nameLen + 1];
    napi_get_value_string_utf8(env, argValues[0], name, nameLen + 1, &nameLen);
    std::string functionName(name);
    delete[] name;

    size_t paramsLen = 0;
    napi_get_value_string_utf8(env, argValues[1], nullptr, 0, &paramsLen);
    char* params = new char[paramsLen + 1];
    napi_get_value_string_utf8(env, argValues[1], params, paramsLen + 1, &paramsLen);
    std::string paramsStr(params);
    delete[] params;

    // JsCall sends action to the __lx_native__ handler in the script
    std::string resultStr = JsAudioEngine::JsvmEngine::GetInstance().JsCall(functionName, paramsStr);

    napi_value result = nullptr;
    napi_create_string_utf8(env, resultStr.c_str(), resultStr.size(), &result);
    return result;
}

// Release the JSVM engine
static napi_value ReleaseEngine(napi_env env, napi_callback_info info) {
    JsAudioEngine::JsvmEngine::GetInstance().ReleaseEngine();
    napi_value result = nullptr;
    napi_get_undefined(env, &result);
    return result;
}

// ============ Event Bridge: JSVM → ArkTS ============

// Data structure passed to ArkTS callback
struct ActionCallbackData {
    std::string action;
    std::string data;
};

// Thread-safe function callback invoked when JSVM calls __lx_native_call__
static void TSFNCallback(napi_env env, napi_value jsCb, void* context, void* data) {
    if (data == nullptr) return;

    ActionCallbackData* cbData = static_cast<ActionCallbackData*>(data);

    // Create the JS object to pass to ArkTS: { action: string, data: string }
    napi_value result = nullptr;
    napi_create_object(env, &result);

    napi_value actionVal = nullptr;
    napi_create_string_utf8(env, cbData->action.c_str(), cbData->action.size(), &actionVal);
    napi_set_named_property(env, result, "action", actionVal);

    napi_value dataVal = nullptr;
    napi_create_string_utf8(env, cbData->data.c_str(), cbData->data.size(), &dataVal);
    napi_set_named_property(env, result, "data", dataVal);

    // Call the ArkTS callback
    napi_value global = nullptr;
    napi_get_global(env, &global);
    napi_value cbResult = nullptr;
    napi_call_function(env, global, jsCb, 1, &result, &cbResult);

    delete cbData;
}

/**
 * Register a callback from ArkTS to receive JSVM events.
 * ArkTS calls: jsAudio.registerCallback((event) => { ... })
 * event = { action: "init"|"request"|"response"|"showUpdateAlert", data: "..." }
 */
static napi_value RegisterCallback(napi_env env, napi_callback_info info) {
    size_t argCount = 1;
    napi_value argValues[1] = {nullptr};
    napi_get_cb_info(env, info, &argCount, argValues, nullptr, nullptr);

    napi_valuetype type;
    napi_typeof(env, argValues[0], &type);
    if (type != napi_function) {
        OH_LOG_ERROR(LOG_APP, "registerCallback: argument must be a function");
        napi_value result = nullptr;
        napi_get_boolean(env, false, &result);
        return result;
    }

    // Clean up previous TSFN if any
    if (g_tsfn != nullptr) {
        napi_release_threadsafe_function(g_tsfn, napi_tsfn_release);
        g_tsfn = nullptr;
    }

    // Create a new thread-safe function
    napi_value resourceName = nullptr;
    napi_create_string_utf8(env, "ActionCallback", NAPI_AUTO_LENGTH, &resourceName);

    napi_status status = napi_create_threadsafe_function(
        env,
        argValues[0],          // js callback
        nullptr,               // async resource
        resourceName,          // resource name
        0,                     // max queue size (0 = unlimited)
        1,                     // initial thread count
        nullptr,               // thread finalize data
        nullptr,               // thread finalize callback
        nullptr,               // context
        TSFNCallback,          // call callback
        &g_tsfn
    );

    if (status != napi_ok) {
        OH_LOG_ERROR(LOG_APP, "Failed to create threadsafe function");
        napi_value result = nullptr;
        napi_get_boolean(env, false, &result);
        return result;
    }

    // Set up the action callback in the engine
    JsAudioEngine::JsvmEngine::GetInstance().SetActionCallback(
        [](const std::string& action, const std::string& data) {
            if (g_tsfn == nullptr) return;
            ActionCallbackData* cbData = new ActionCallbackData{action, data};
            napi_call_threadsafe_function(g_tsfn, cbData, napi_tsfn_nonblocking);
        }
    );

    OH_LOG_INFO(LOG_APP, "registerCallback: callback registered successfully");

    napi_value result = nullptr;
    napi_get_boolean(env, true, &result);
    return result;
}

/**
 * Send an event from ArkTS back to JSVM.
 * ArkTS calls: jsAudio.sendToJs(action: string, data: string): string
 * This calls __lx_native__(key, action, data) in the JSVM.
 */
static napi_value SendToJs(napi_env env, napi_callback_info info) {
    size_t argCount = 2;
    napi_value argValues[2] = {nullptr};
    napi_get_cb_info(env, info, &argCount, argValues, nullptr, nullptr);

    size_t actionLen = 0;
    napi_get_value_string_utf8(env, argValues[0], nullptr, 0, &actionLen);
    char* action = new char[actionLen + 1];
    napi_get_value_string_utf8(env, argValues[0], action, actionLen + 1, &actionLen);
    std::string actionStr(action);
    delete[] action;

    size_t dataLen = 0;
    napi_get_value_string_utf8(env, argValues[1], nullptr, 0, &dataLen);
    char* data = new char[dataLen + 1];
    napi_get_value_string_utf8(env, argValues[1], data, dataLen + 1, &dataLen);
    std::string dataStr(data);
    delete[] data;

    std::string resultStr = JsAudioEngine::JsvmEngine::GetInstance().JsCall(actionStr, dataStr);

    napi_value result = nullptr;
    napi_create_string_utf8(env, resultStr.c_str(), resultStr.size(), &result);
    return result;
}

// ============ Module Registration ============

EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor desc[] = {
        {"createEngine", nullptr, CreateEngine, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"executeScript", nullptr, ExecuteScript, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"callFunction", nullptr, CallFunction, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"releaseEngine", nullptr, ReleaseEngine, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"registerCallback", nullptr, RegisterCallback, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"sendToJs", nullptr, SendToJs, nullptr, nullptr, nullptr, napi_default, nullptr}
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    return exports;
}
EXTERN_C_END

static napi_module demoModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "jsaudioengine",
    .nm_priv = ((void*)0),
    .reserved = {0},
};

extern "C" __attribute__((constructor)) void RegisterJSAudioEngineModule(void) {
    napi_module_register(&demoModule);
}
