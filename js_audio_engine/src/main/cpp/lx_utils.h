#ifndef LX_UTILS_H
#define LX_UTILS_H

#include <string>
#include <vector>

namespace JsAudioEngine {

class LxUtils {
public:
    static std::string Md5(const std::string& input);
    static std::string Base64Encode(const std::string& input);
    static std::string Base64Decode(const std::string& input);
    static std::string UrlDecode(const std::string& input);
};

} // namespace JsAudioEngine

#endif // LX_UTILS_H
