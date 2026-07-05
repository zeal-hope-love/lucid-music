#include "lx_utils.h"
#include <sstream>
#include <iomanip>
#include <cmath>
#include <cstdint>
#include <cstring>

namespace JsAudioEngine {

// Pure C++ MD5 (RFC 1321)
std::string LxUtils::Md5(const std::string& input) {
    uint32_t state[4] = { 0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476 };
    std::vector<unsigned char> msg(input.begin(), input.end());
    uint64_t bitLen = msg.size() * 8;
    msg.push_back(0x80);
    while ((msg.size() + 8) % 64 != 0) msg.push_back(0);
    for (int i = 0; i < 8; i++) msg.push_back((bitLen >> (i * 8)) & 0xFF);

    uint32_t K[64];
    for (int i = 0; i < 64; i++) K[i] = (uint32_t)(fabs(sin(i + 1.0)) * 4294967296.0);
    uint32_t S[64] = {7,12,17,22,7,12,17,22,7,12,17,22,7,12,17,22,
                       5,9,14,20,5,9,14,20,5,9,14,20,5,9,14,20,
                       4,11,16,23,4,11,16,23,4,11,16,23,4,11,16,23,
                       6,10,15,21,6,10,15,21,6,10,15,21,6,10,15,21};

    #define LR(x,c) (((x)<<(c))|((x)>>(32-(c))))
    for (size_t b = 0; b < msg.size(); b += 64) {
        uint32_t M[16];
        for (int i = 0; i < 16; i++)
            M[i] = msg[b+i*4] | (msg[b+i*4+1]<<8) | (msg[b+i*4+2]<<16) | (msg[b+i*4+3]<<24);
        uint32_t a = state[0], bb = state[1], c = state[2], d = state[3];
        for (int i = 0; i < 64; i++) {
            uint32_t f, g;
            if (i < 16) { f = (bb & c) | (~bb & d); g = i; }
            else if (i < 32) { f = (d & bb) | (~d & c); g = (5*i+1)%16; }
            else if (i < 48) { f = bb ^ c ^ d; g = (3*i+5)%16; }
            else { f = c ^ (bb | ~d); g = (7*i)%16; }
            uint32_t t = d; d = c; c = bb;
            bb = bb + LR(a + f + K[i] + M[g], S[i]);
            a = t;
        }
        state[0] += a; state[1] += bb; state[2] += c; state[3] += d;
    }
    #undef LR

    std::ostringstream oss;
    for (int i = 0; i < 4; i++)
        for (int j = 0; j < 4; j++)
            oss << std::hex << std::setfill('0') << std::setw(2) << ((state[i] >> (j*8)) & 0xFF);
    return oss.str();
}

std::string LxUtils::Base64Encode(const std::string& input) {
    static const char* base64Chars =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    std::string result;
    int val = 0;
    int valb = -6;
    for (unsigned char c : input) {
        val = (val << 8) + c;
        valb += 8;
        while (valb >= 0) {
            result.push_back(base64Chars[(val >> valb) & 0x3F]);
            valb -= 6;
        }
    }
    if (valb > -6) {
        result.push_back(base64Chars[((val << 8) >> (valb + 8)) & 0x3F]);
    }
    while (result.size() % 4) {
        result.push_back('=');
    }
    return result;
}

std::string LxUtils::Base64Decode(const std::string& input) {
    static const int decodeTable[256] = {
        -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
        -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
        -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,62,-1,-1,-1,63,
        52,53,54,55,56,57,58,59,60,61,-1,-1,-1,-1,-1,-1,
        -1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,
        15,16,17,18,19,20,21,22,23,24,25,-1,-1,-1,-1,-1,
        -1,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,
        41,42,43,44,45,46,47,48,49,50,51,-1,-1,-1,-1,-1,
        -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
        -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
        -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
        -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
        -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
        -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
        -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
        -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1
    };
    std::string result;
    int val = 0, valb = -8;
    for (unsigned char c : input) {
        if (c == '=') break;
        int decoded = decodeTable[c];
        if (decoded == -1) continue;
        val = (val << 6) + decoded;
        valb += 6;
        if (valb >= 0) {
            result.push_back((char)((val >> valb) & 0xFF));
            valb -= 8;
        }
    }
    return result;
}

std::string LxUtils::UrlDecode(const std::string& input) {
    std::string result;
    for (size_t i = 0; i < input.size(); i++) {
        if (input[i] == '%' && i + 2 < input.size()) {
            auto hv = [](char c) -> int {
                if (c >= '0' && c <= '9') return c - '0';
                if (c >= 'a' && c <= 'f') return c - 'a' + 10;
                if (c >= 'A' && c <= 'F') return c - 'A' + 10;
                return -1;
            };
            int h1 = hv(input[i+1]), h2 = hv(input[i+2]);
            if (h1 >= 0 && h2 >= 0) { result += (char)(h1*16+h2); i += 2; }
            else result += input[i];
        } else {
            result += input[i];
        }
    }
    return result;
}

} // namespace JsAudioEngine
