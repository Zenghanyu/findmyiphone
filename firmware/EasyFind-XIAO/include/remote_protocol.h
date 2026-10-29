#pragma once
#include <stddef.h>
#include <stdint.h>

namespace remote {
constexpr uint8_t kMaxDelay = 30;
constexpr uint8_t kCapabilities = 0x1f;
constexpr const char* kService = "AEBB1000-7F4A-4A38-8CF0-18D6BB28B273";
constexpr const char* kCommand = "AEBB1001-7F4A-4A38-8CF0-18D6BB28B273";
constexpr const char* kResponse = "AEBB1002-7F4A-4A38-8CF0-18D6BB28B273";
inline uint64_t read64(const uint8_t* bytes) {
    uint64_t value = 0;
    for (uint8_t i = 0; i < 8; ++i) value |= uint64_t(bytes[i]) << (8 * i);
    return value;
}
inline void write64(uint64_t value, uint8_t* bytes) {
    for (uint8_t i = 0; i < 8; ++i) bytes[i] = uint8_t(value >> (8 * i));
}
struct Request {
    uint8_t opcode; uint16_t sequence; uint8_t length; uint8_t delay;
    uint64_t findID; uint8_t findStatus;
};
inline bool decode(const uint8_t* data, size_t length, Request& out) {
    if (!data || length < 7 || length > 20 || data[0] != 0x53 || data[1] != 0x46 ||
        data[2] != 1 || length != size_t(7 + data[6])) return false;
    const uint16_t seq = uint16_t(data[4]) | (uint16_t(data[5]) << 8);
    if (!seq || data[3] < 1 || data[3] > 4) return false;
    out = {data[3], seq, data[6], uint8_t(length > 7 ? data[7] : 0), 0, 0};
    if (data[3] == 3 && data[6] == 9) {
        out.findID = read64(data + 7);
        out.findStatus = data[15];
    }
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
    switch (request.opcode) {
        case 1: case 4: return request.length == 0 ? 0 : 1;
        case 2:
            if (request.length != 1 || request.delay > kMaxDelay) return 1;
            return counting ? 4 : 0;
        case 3: return request.length == 9 && request.findID && request.findStatus <= 2 ? 0 : 1;
        default: return 2;
    }
}
// Monotonic milliseconds, wrap-safe for intervals shorter than 2^31 ms.
inline uint8_t remaining(uint32_t now, uint32_t deadline) {
    const int32_t difference = int32_t(deadline - now);
    return difference <= 0 ? 0 : uint8_t((uint32_t(difference) + 999) / 1000);
}
}
