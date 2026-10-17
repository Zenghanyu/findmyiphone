#include "find_delivery.h"
#include <cassert>
#include <cstdio>

using remote::FindDelivery;
using remote::FindDeliveryKind;

int main() {
    // No link/subscription ordering can release a pending request before negotiation.
    FindDelivery pending;
    assert(!pending.request(100, 0));
    assert(pending.request(100, 0x1122334455667788ULL));
    assert(pending.remainingSeconds(100) == 30);
    assert(pending.due(100, false) == FindDeliveryKind::none);
    assert(pending.due(100, true) == FindDeliveryKind::none);
    pending.enableReliable();
    assert(pending.due(100, false) == FindDeliveryKind::none);
    assert(pending.due(100, true) == FindDeliveryKind::reliable);

    // Submitting a reliable notification, including a lost notification, needs ACK.
    pending.attempted(100, FindDeliveryKind::reliable, true);
    assert(pending.pending());
    assert(pending.attempts() == 1);
    assert(pending.due(2099, true) == FindDeliveryKind::none);
    assert(pending.due(2100, true) == FindDeliveryKind::reliable);
    pending.attempted(2100, FindDeliveryKind::reliable, false);
    assert(pending.due(4099, true) == FindDeliveryKind::none);
    assert(pending.due(4100, true) == FindDeliveryKind::reliable);

    // Repeated presses neither replace the stable ID nor extend its expiry.
    assert(!pending.request(20000, 99));
    assert(pending.id() == 0x1122334455667788ULL);
    assert(pending.remainingSeconds(20000) == 11);
    assert(pending.remainingSeconds(30099) == 1);
    assert(pending.due(30100, true) == FindDeliveryKind::none);
    assert(pending.expire(30100));
    assert(!pending.pending());
    assert(!pending.expire(30101));

    // Expired requests do not come back after reconnect; a new press can start fresh.
    pending.connectionChanged();
    pending.enableReliable();
    assert(pending.due(30200, true) == FindDeliveryKind::none);
    assert(pending.request(30200, 99));
    assert(!pending.acknowledge(30200, 0x1122334455667788ULL, 0));
    assert(pending.pending());
    assert(!pending.acknowledge(30200, 99, 3));
    assert(pending.acknowledge(30200, 99, 0));
    assert(!pending.acknowledge(30200, 99, 0));
    assert(!pending.pending());

    // All terminal outcomes stop delivery. Stale ACKs cannot clear a newer request.
    for (uint8_t status = 0; status <= 2; ++status) {
        assert(pending.request(40000 + status, 100 + status));
        assert(!pending.acknowledge(40000 + status, 99, status));
        assert(pending.acknowledge(40000 + status, 100 + status, status));
    }
    assert(pending.request(50000, 200));
    assert(!pending.acknowledge(80000, 200, 0));
    assert(!pending.pending());

    // A disconnect preserves the request and TTL, but resets delivery capability.
    FindDelivery reconnect;
    assert(reconnect.request(1000, 55));
    reconnect.enableReliable();
    reconnect.attempted(1000, FindDeliveryKind::reliable, true);
    reconnect.connectionChanged();
    assert(reconnect.pending() && reconnect.id() == 55 && !reconnect.reliable());
    assert(reconnect.remainingSeconds(2000) == 29);
    assert(reconnect.due(2000, true) == FindDeliveryKind::none);
    reconnect.enableReliable();
    assert(reconnect.due(2000, true) == FindDeliveryKind::reliable);
    assert(reconnect.acknowledge(2000, 55, 0));
    FindDelivery reboot;
    assert(!reboot.pending() && !reboot.reliable());

    // Old Apps receive one legacy event after their first READ_CONFIG + grace.
    FindDelivery legacy;
    assert(legacy.request(1000, 1));
    assert(legacy.due(10000, true) == FindDeliveryKind::none);
    legacy.configurationRead(10000);
    assert(legacy.due(10499, true) == FindDeliveryKind::none);
    legacy.configurationRead(10499); // A retry must not restart negotiation grace.
    assert(legacy.due(10500, true) == FindDeliveryKind::legacy);
    legacy.attempted(10500, FindDeliveryKind::legacy, false);
    assert(legacy.pending());
    assert(legacy.due(12499, true) == FindDeliveryKind::none);
    assert(legacy.due(12500, true) == FindDeliveryKind::legacy);
    legacy.attempted(12500, FindDeliveryKind::legacy, true);
    assert(!legacy.pending());
    assert(legacy.due(14500, true) == FindDeliveryKind::none);
    assert(legacy.request(15000, 2));
    assert(legacy.due(15000, true) == FindDeliveryKind::legacy);

    // New Apps may enable before or after config. No legacy event precedes enable.
    FindDelivery newApp;
    assert(newApp.request(0, 123));
    newApp.configurationRead(0);
    newApp.enableReliable();
    assert(newApp.due(1, true) == FindDeliveryKind::reliable);
    newApp.connectionChanged();
    assert(newApp.due(5000, true) == FindDeliveryKind::none);
    newApp.configurationRead(5000);
    newApp.enableReliable();
    assert(newApp.due(5000, true) == FindDeliveryKind::reliable);

    // TTL, retry and negotiation all work across the uint32_t millisecond wrap.
    FindDelivery wrap;
    const uint32_t began = 0xfffffff0u;
    assert(wrap.request(began, 88));
    wrap.configurationRead(began);
    assert(wrap.due(began + 499u, true) == FindDeliveryKind::none);
    assert(wrap.due(began + 500u, true) == FindDeliveryKind::legacy);
    wrap.enableReliable();
    wrap.attempted(began, FindDeliveryKind::reliable, true);
    assert(wrap.due(began + 1999u, true) == FindDeliveryKind::none);
    assert(wrap.due(began + 2000u, true) == FindDeliveryKind::reliable);
    assert(wrap.remainingSeconds(began + 29999u) == 1);
    assert(wrap.remainingSeconds(began + 30000u) == 0);
    assert(wrap.expire(began + 30000u));

    puts("PASS: reliable find lifetime, retries, ACKs, coalescing, reconnect, legacy and clock wrap");
}
