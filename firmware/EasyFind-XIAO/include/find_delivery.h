#pragma once
#include <stdint.h>

namespace remote {
constexpr uint32_t kFindLifetimeMs = 30000;
constexpr uint32_t kFindRetryMs = 2000;
constexpr uint32_t kLegacyNegotiationMs = 500;

enum class FindDeliveryKind { none, legacy, reliable };

// Owned exclusively by loop(). BLE callbacks only publish link state / commands.
// All time comparisons use unsigned elapsed milliseconds, including millis() wrap.
// A pending request is RAM-only: disconnect preserves it, reboot discards it.
class FindDelivery {
public:
    bool request(uint32_t now, uint64_t id) {
        expire(now);
        if (pending_ || !id) return false; // Coalesce presses without extending TTL.
        pending_ = true;
        id_ = id;
        createdAt_ = now;
        attempted_ = false;
        attempts_ = 0;
        return true;
    }

    void connectionChanged() {
        reliable_ = false;
        configurationRead_ = false;
        attempted_ = false; // A restored link can send immediately once negotiated.
    }

    void enableReliable() { reliable_ = true; }

    void configurationRead(uint32_t now) {
        if (!configurationRead_) {
            configurationRead_ = true;
            configurationReadAt_ = now;
        }
    }

    bool expire(uint32_t now) {
        if (!pending_ || uint32_t(now - createdAt_) < kFindLifetimeMs) return false;
        pending_ = false;
        return true;
    }

    FindDeliveryKind due(uint32_t now, bool linkReady) const {
        if (!pending_ || !linkReady || !remainingSeconds(now)) return FindDeliveryKind::none;
        if (attempted_ && uint32_t(now - lastAttemptAt_) < kFindRetryMs) return FindDeliveryKind::none;
        if (reliable_) return FindDeliveryKind::reliable;
        // CCCD restoration alone must never send legacy before a new App enables ACKs.
        if (!configurationRead_ || uint32_t(now - configurationReadAt_) < kLegacyNegotiationMs)
            return FindDeliveryKind::none;
        return FindDeliveryKind::legacy;
    }

    void attempted(uint32_t now, FindDeliveryKind kind, bool queued) {
        if (!pending_ || kind == FindDeliveryKind::none) return;
        attempted_ = true;
        lastAttemptAt_ = now;
        ++attempts_;
        // A successful notify only means queued, so reliable delivery needs an ACK.
        // Old Apps have no ACK; after one queued legacy event they retain v0.1 behavior.
        if (kind == FindDeliveryKind::legacy && queued) pending_ = false;
    }

    bool acknowledge(uint32_t now, uint64_t id, uint8_t status) {
        expire(now);
        if (!pending_ || id != id_ || status > 2) return false;
        pending_ = false;
        return true;
    }

    uint8_t remainingSeconds(uint32_t now) const {
        if (!pending_) return 0;
        const uint32_t elapsed = now - createdAt_;
        if (elapsed >= kFindLifetimeMs) return 0;
        return uint8_t((kFindLifetimeMs - elapsed + 999) / 1000);
    }

    bool pending() const { return pending_; }
    bool reliable() const { return reliable_; }
    uint64_t id() const { return id_; }
    uint32_t attempts() const { return attempts_; }

private:
    bool pending_ = false, reliable_ = false, configurationRead_ = false, attempted_ = false;
    uint64_t id_ = 0;
    uint32_t createdAt_ = 0, configurationReadAt_ = 0, lastAttemptAt_ = 0, attempts_ = 0;
};
}
