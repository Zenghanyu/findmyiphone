#include <Arduino.h>
#include <NimBLEDevice.h>
#include <NimBLEHIDDevice.h>
#include <Preferences.h>
#include <atomic>
#include "remote_protocol.h"

namespace {
constexpr char kName[] = "EasyFind Remote";
constexpr uint8_t kButton = 0;
// Consumer Control: Report ID 1, one Volume Increment bit and seven padding bits.
const uint8_t reportMap[] = {
    0x05,0x0c, 0x09,0x01, 0xa1,0x01, 0x85,0x01,
    0x15,0x00, 0x25,0x01, 0x09,0xe9, 0x75,0x01, 0x95,0x01, 0x81,0x02,
    0x75,0x07, 0x95,0x01, 0x81,0x03, 0xc0
};
Preferences settings;
bool storageReady = false;
uint8_t savedDelay = 3;
bool counting = false, keyDown = false;
uint32_t deadline = 0, releaseAt = 0;
uint8_t lastRemaining = 0;
std::atomic<bool> connected{false}, encrypted{false}, hidSubscribed{false}, responseSubscribed{false};
std::atomic<uint32_t> generation{0};
std::atomic<bool> linkLost{false};
NimBLECharacteristic* inputReport = nullptr;
NimBLECharacteristic* response = nullptr;
struct Command { uint8_t bytes[20]; uint8_t size; uint32_t generation; };
QueueHandle_t commandQueue = nullptr;
bool hasCached = false;
Command cached{};
uint8_t cachedReply[20];
size_t cachedReplyLength = 0;

bool hidReady() { return connected && encrypted && hidSubscribed; }
void hexLog(const char* prefix, const uint8_t* bytes, size_t size) {
    Serial.print(prefix);
    for (size_t i = 0; i < size; ++i) Serial.printf("%02X", bytes[i]);
    Serial.println();
}
void notify(const uint8_t* bytes, size_t size) {
    response->setValue(bytes, size);
    if (connected && encrypted && responseSubscribed) response->notify();
}
void event(uint8_t type, uint8_t left = 0) {
    uint8_t bytes[9], payload[] = {type, left};
    const auto size = remote::frame(0xe0, 0, payload, 2, bytes);
    notify(bytes, size);
    hexLog("event=", bytes, size);
}
void status() {
    Serial.printf("remote.status version=%s name=%s delay=%u storage=%u connected=%u encrypted=%u hid_subscribed=%u app_subscribed=%u counting=%u remaining=%u\n",
        FIRMWARE_VERSION, kName, savedDelay, storageReady, bool(connected), bool(encrypted), bool(hidSubscribed), bool(responseSubscribed), counting,
        counting ? remote::remaining(millis(), deadline) : 0);
}
bool persist(uint8_t value) {
    if (!storageReady) return false;
    if (savedDelay == value) return true;
    if (settings.putUChar("delay", value) != 1 || settings.getUChar("delay", 255) != value) return false;
    savedDelay = value;
    return true;
}
void process(const Command& command, bool serialOnly) {
    remote::Request request{};
    if (!remote::decode(command.bytes, command.size, request)) {
        Serial.println("command.rejected=invalid_frame"); return;
    }
    if (!serialOnly && (command.generation != generation || !encrypted || !responseSubscribed)) return;
    if (!serialOnly && hasCached && cached.generation == command.generation && cached.bytes[4] == command.bytes[4] && cached.bytes[5] == command.bytes[5]) {
        if (cached.size == command.size && memcmp(cached.bytes, command.bytes, command.size) == 0) {
            notify(cachedReply, cachedReplyLength); return;
        }
        Serial.println("command.rejected=sequence_reused"); return;
    }
    uint8_t result = remote::validate(request, counting);
    if (!result && !storageReady) result = 3;
    if (request.opcode == 2 && !result && !persist(request.delay)) result = 3;
    const uint8_t payload[] = {result, savedDelay, remote::kMaxDelay, remote::kCapabilities};
    uint8_t reply[20];
    const size_t length = remote::frame(request.opcode | 0x80, request.sequence, payload, request.opcode == 1 ? 4 : 2, reply);
    hexLog(serialOnly ? "serial.reply=" : "ble.reply=", reply, length);
    if (!serialOnly) {
        notify(reply, length);
        cached = command; memcpy(cachedReply, reply, length); cachedReplyLength = length; hasCached = true;
    }
}
void cancel() {
    if (counting) { counting = false; event(4); }
}
void shutter() {
    if (!hidReady()) { Serial.println("shutter.ignored=hid_not_ready"); return; }
    uint8_t pressed = 1;
    inputReport->setValue(&pressed, 1);
    inputReport->notify();
    keyDown = true;
    releaseAt = millis() + 50;
    event(3);
    Serial.println("hid.volume_increment=sent (not proof of photo capture)");
}
void shortPress() {
    if (counting) { cancel(); return; }
    if (!hidReady() || keyDown) { Serial.println("button.short=ignored_hid_not_ready_or_busy"); return; }
    if (!savedDelay) { shutter(); return; }
    counting = true;
    deadline = millis() + uint32_t(savedDelay) * 1000;
    lastRemaining = savedDelay;
    event(1, savedDelay);
}
void longPress() {
    cancel();
    if (!connected || !encrypted || !responseSubscribed) {
        Serial.println("button.long=ignored_app_not_subscribed"); return;
    }
    event(5);
}
class ServerCallbacks : public NimBLEServerCallbacks {
    void onConnect(NimBLEServer*) override {
        ++generation;
        connected = true;
        encrypted = false;
        Serial.println("ble.connected=1");
    }
    void onDisconnect(NimBLEServer*) override {
        connected = false; encrypted = false; hidSubscribed = false; responseSubscribed = false;
        ++generation; linkLost = true;
        NimBLEDevice::startAdvertising();
        Serial.println("ble.connected=0");
    }
    void onAuthenticationComplete(ble_gap_conn_desc* desc) override {
        encrypted = desc->sec_state.encrypted;
        Serial.printf("ble.encrypted=%u bonded=%u\n", desc->sec_state.encrypted, desc->sec_state.bonded);
        if (!encrypted) NimBLEDevice::getServer()->disconnect(desc->conn_handle);
    }
};
class CommandCallbacks : public NimBLECharacteristicCallbacks {
    void onWrite(NimBLECharacteristic* characteristic) override {
        const auto value = characteristic->getValue();
        if (!encrypted || value.size() > 20 || value.size() < 7) return;
        Command command{}; command.size = value.size(); command.generation = generation;
        memcpy(command.bytes, value.data(), command.size);
        if (xQueueSend(commandQueue, &command, 0) != pdTRUE) Serial.println("command.queue=full");
    }
};
class SubscriptionCallbacks : public NimBLECharacteristicCallbacks {
    void onSubscribe(NimBLECharacteristic* characteristic, ble_gap_conn_desc*, uint16_t value) override {
        if (characteristic == inputReport) hidSubscribed = (value & 1) != 0;
        if (characteristic == response) responseSubscribed = (value & 1) != 0;
        Serial.printf("ble.subscription hid=%u app=%u\n", bool(hidSubscribed), bool(responseSubscribed));
    }
};
ServerCallbacks serverCallbacks;
CommandCallbacks commandCallbacks;
SubscriptionCallbacks subscriptionCallbacks;

void pollButton() {
    static bool rawPrevious = false, stable = false;
    static uint32_t changedAt = 0, pressedAt = 0;
    const uint32_t now = millis();
    const bool raw = digitalRead(kButton) == LOW;
    if (raw != rawPrevious) { rawPrevious = raw; changedAt = now; }
    if (raw == stable || now - changedAt < 30) return;
    stable = raw;
    if (stable) { pressedAt = now; return; }
    if (now - pressedAt >= 1000) longPress(); else shortPress();
}
void serialCommands() {
    static char buffer[100]; static size_t used = 0; static bool overflow = false;
    while (Serial.available()) {
        const char c = Serial.read();
        if (c == '\r') continue;
        if (c != '\n') {
            if (used + 1 < sizeof(buffer) && !overflow) buffer[used++] = c; else overflow = true;
            continue;
        }
        buffer[used] = 0;
        if (overflow) Serial.println("serial.error=too_long");
        else if (!strcmp(buffer, "STATUS")) status();
        else if (!strcmp(buffer, "PRESS_SHORT")) shortPress();
        else if (!strcmp(buffer, "PRESS_LONG")) longPress();
        else if (!strcmp(buffer, "CANCEL")) cancel();
        else if (!strcmp(buffer, "REBOOT")) { Serial.println("remote.reboot=requested"); Serial.flush(); ESP.restart(); }
        else if (!strncmp(buffer, "FRAME ", 6)) {
            const char* hex = buffer + 6; size_t length = strlen(hex);
            Command command{}; bool valid = length % 2 == 0 && length <= 40 && length >= 14;
            for (size_t i = 0; valid && i < length / 2; ++i) {
                const char a = hex[2*i], b = hex[2*i+1];
                if (!isxdigit(a) || !isxdigit(b)) { valid = false; break; }
                char pair[] = {a,b,0}; command.bytes[i] = strtoul(pair, nullptr, 16);
            }
            command.size = length / 2;
            if (valid) process(command, true); else Serial.println("serial.error=invalid_hex");
        } else if (used) Serial.println("serial.error=unknown_command");
        used = 0; overflow = false;
    }
}
}

void setup() {
    Serial.begin(115200);
    const uint32_t began = millis();
    while (!Serial && millis() - began < 1500) delay(10);
    pinMode(kButton, INPUT_PULLUP);
    storageReady = settings.begin("ef-remote", false);
    savedDelay = settings.getUChar("delay", 3);
    if (savedDelay > remote::kMaxDelay) savedDelay = 3;
    commandQueue = xQueueCreate(8, sizeof(Command));
    if (!commandQueue) { Serial.println("fatal=queue_alloc"); return; }
    NimBLEDevice::init(kName);
    NimBLEDevice::setSecurityAuth(true, false, true);
    NimBLEDevice::setSecurityIOCap(BLE_HS_IO_NO_INPUT_OUTPUT);
    auto* server = NimBLEDevice::createServer();
    server->setCallbacks(&serverCallbacks, false);
    auto* hid = new NimBLEHIDDevice(server);
    hid->manufacturer()->setValue("EasyFind prototype");
    // Bench identity follows the XIAO board's USB IDs, not a production product allocation.
    hid->pnp(0x02, 0x2886, 0x0056, 0x0100);
    hid->hidInfo(0, 0x02);
    hid->reportMap(const_cast<uint8_t*>(reportMap), sizeof(reportMap));
    inputReport = hid->inputReport(1);
    inputReport->setCallbacks(&subscriptionCallbacks);
    const uint8_t released = 0;
    inputReport->setValue(&released, 1);
    hid->startServices();
    hid->setBatteryLevel(100); // USB-powered bench prototype, not a measured battery value.
    auto* service = server->createService(remote::kService);
    auto* command = service->createCharacteristic(remote::kCommand, NIMBLE_PROPERTY::WRITE | NIMBLE_PROPERTY::WRITE_ENC);
    command->setCallbacks(&commandCallbacks);
    response = service->createCharacteristic(remote::kResponse, NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::READ_ENC | NIMBLE_PROPERTY::NOTIFY);
    response->setCallbacks(&subscriptionCallbacks);
    service->start();
    auto* advertising = NimBLEDevice::getAdvertising();
    advertising->setAppearance(0x03c0);
    advertising->addServiceUUID(hid->hidService()->getUUID());
    advertising->addServiceUUID(remote::kService);
    advertising->setScanResponse(true);
    const bool advertisingStarted = advertising->start();
    Serial.printf("ble.advertising=%u\n", advertisingStarted);
    Serial.println("remote.boot sd=untouched microphone=off button=GPIO0 short=photo long_1s=find_phone");
    Serial.println("commands: STATUS | FRAME <hex> | PRESS_SHORT | PRESS_LONG | CANCEL | REBOOT");
    status();
}
void loop() {
    if (!commandQueue) { delay(100); return; }
    if (linkLost.exchange(false)) {
        counting = false; keyDown = false; hasCached = false;
        const uint8_t released = 0; inputReport->setValue(&released, 1);
    }
    Command command{};
    if (xQueueReceive(commandQueue, &command, 0) == pdTRUE) process(command, false);
    serialCommands();
    pollButton();
    if (keyDown && int32_t(millis() - releaseAt) >= 0) {
        const uint8_t released = 0;
        inputReport->setValue(&released, 1);
        if (hidReady()) inputReport->notify();
        keyDown = false;
    }
    if (counting) {
        if (!hidReady()) cancel();
        else {
            const uint8_t left = remote::remaining(millis(), deadline);
            if (!left) { counting = false; shutter(); }
            else if (left != lastRemaining) { lastRemaining = left; event(2, left); }
        }
    }
    delay(2);
}
