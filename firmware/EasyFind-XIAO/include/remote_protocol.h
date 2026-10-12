#pragma once
#include <stddef.h>
#include <stdint.h>

namespace remote {
constexpr uint8_t kMaxDelay = 30;
constexpr uint8_t kCapabilities = 0x0f;
constexpr const char* kService = "AEBB1000-7F4A-4A38-8CF0-18D6BB28B273";
constexpr const char* kCommand = "AEBB1001-7F4A-4A38-8CF0-18D6BB28B273";
constexpr const char* kResponse = "AEBB1002-7F4A-4A38-8CF0-18D6BB28B273";
struct Request { uint8_t opcode; uint16_t sequence; uint8_t length; uint8_t delay; };
inline bool decode(const uint8_t* data, size_t length, Request& out) {
    if (!data || length < 7 || length > 20 || data[0] != 0x53 || data[1] != 0x46 ||
        data[2] != 1 || length != size_t(7 + data[6])) return false;
    const uint16_t seq = uint16_t(data[4]) | (uint16_t(data[5]) << 8);
    if (!seq || (data[3] != 1 && data[3] != 2)) return false;
    out = {data[3], seq, data[6], uint8_t(length > 7 ? data[7] : 0)};
    return true;
}
inline size_t frame(uint8_t opcode, uint16_t sequence, const uint8_t* payload, uint8_t size, uint8_t* dest) {
    if (size > 13) return 0;
    dest[0] = 0x53; dest[1] = 0x46; dest[2] = 1; dest[3] = opcode;
    dest[4] = uint8_t(sequence); dest[5] = uint8_t(sequence >> 8); dest[6] = size;
    for (uint8_t i = 0; i < size; ++i) dest[7 + i] = payload[i];
    return 7 + size;
}
inline uint8_t validate(const Request& request, bool counting) {
    if (request.opcode == 1) return request.length == 0 ? 0 : 1;
    if (request.length != 1 || request.delay > kMaxDelay) return 1;
    return counting ? 4 : 0;
}
// Monotonic milliseconds, wrap-safe for intervals shorter than 2^31 ms.
inline uint8_t remaining(uint32_t now, uint32_t deadline) {
    const int32_t difference = int32_t(deadline - now);
    return difference <= 0 ? 0 : uint8_t((uint32_t(difference) + 999) / 1000);
}
}
