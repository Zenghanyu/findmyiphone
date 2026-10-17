import Foundation

@main
struct PhoneFindDeliveryTests {
    @MainActor
    static func main() async throws {
        typealias Wire = SelfieStickProtocol
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("receipts.json")
        let request = Wire.PhoneFindRequest(id: 0x0807060504030201, remainingSeconds: 30)
        let bytes = try request.eventFrame().encoded()
        precondition(Array(bytes) == [0x53,0x46,1,0xe0,0,0,11,5,0,1,2,3,4,5,6,7,8,30])
        let decoded = try Wire.Frame.decode(bytes)
        precondition(Wire.PhoneFindRequest.decode(decoded) == request)
        let ack = try request.acknowledgement(sequence: 7, disposition: .accepted).encoded()
        precondition(Array(ack) == [0x53,0x46,1,3,7,0,9,1,2,3,4,5,6,7,8,0])
        for remaining: UInt8 in [0,31,255] {
            precondition(Wire.PhoneFindRequest.decode(Wire.PhoneFindRequest(id: 1, remainingSeconds: remaining).eventFrame()) == nil)
        }
        precondition(Wire.PhoneFindRequest.decode(Wire.PhoneFindRequest(id: 0, remainingSeconds: 30).eventFrame()) == nil)
        precondition(Wire.PhoneFindRequest.decode(.init(opcode: .event, sequence: 0, payload: [5,0])) == nil)

        var now: TimeInterval = 100
        let store = PhoneFindReceiptStore(url: url)
        let delivery = PhoneFindDelivery(store: store, uptime: { now })
        var submissions = 0, acknowledgements = 0
        var release: CheckedContinuation<Wire.PhoneFindDisposition?, Never>?
        let first = Task { @MainActor in
            await delivery.receive(request, submit: {
                submissions += 1
                return await withCheckedContinuation { release = $0 }
            }, acknowledge: { _ in acknowledgements += 1 })
        }
        while release == nil { await Task.yield() }
        precondition(acknowledgements == 0, "Do not ACK before the system accepts")
        let concurrent = await delivery.receive(request, submit: { fatalError("Concurrent duplicate scheduled twice") },
                                                 acknowledge: { _ in acknowledgements += 1 })
        precondition(concurrent == .inFlight)
        release?.resume(returning: .accepted)
        let firstResult = await first.value
        precondition(firstResult == .handled && submissions == 1 && acknowledgements == 1)
        let restored = PhoneFindDelivery(store: PhoneFindReceiptStore(url: url))
        let duplicate = await restored.receive(request, submit: { fatalError("Durable duplicate scheduled twice") },
                                               acknowledge: { disposition in
            precondition(disposition == .accepted); acknowledgements += 1
        })
        precondition(duplicate == .duplicate && acknowledgements == 2)

        let temporaryFailure = Wire.PhoneFindRequest(id: 2, remainingSeconds: 3)
        let retry = await delivery.receive(temporaryFailure, submit: { nil }, acknowledge: { _ in fatalError("ACK on failure") })
        precondition(retry == .retry)
        now += 4
        let expired = await delivery.receive(temporaryFailure, submit: { fatalError("Expired retry") },
                                              acknowledge: { _ in fatalError("Expired ACK") })
        precondition(expired == .expired)
        now += 120
        let longDelayed = await delivery.receive(temporaryFailure, submit: { fatalError("A delayed event renewed its TTL") },
                                                  acknowledge: { _ in fatalError("Expired delayed ACK") })
        precondition(longDelayed == .expired)
        for disposition: Wire.PhoneFindDisposition in [.disabled, .unauthorized] {
            let terminal = Wire.PhoneFindRequest(id: disposition == .disabled ? 3 : 4, remainingSeconds: 30)
            let result = await delivery.receive(terminal, submit: { disposition }, acknowledge: { precondition($0 == disposition) })
            precondition(result == .handled)
        }
        // Write failures must not publish an ACK or a receipt.
        let blocker = root.appendingPathComponent("blocked")
        try Data([1]).write(to: blocker)
        let badStore = PhoneFindReceiptStore(url: blocker.appendingPathComponent("receipts"))
        let broken = PhoneFindDelivery(store: badStore)
        let failedWrite = await broken.receive(request, submit: { .accepted }, acknowledge: { _ in fatalError("ACK before durable receipt") })
        precondition(failedWrite == .storageFailure && badStore.disposition(for: request.id) == nil)
        let retryWrite = await broken.receive(request, submit: { fatalError("Storage retry resubmitted the alarm") },
                                               acknowledge: { _ in fatalError("Storage retry ACK") })
        precondition(retryWrite == .storageFailure)
        // Legacy configuration remains compatible.
        let legacy = Wire.Request(sequence: 1, kind: .read)
        let config = try legacy.confirmedConfiguration(from: .init(opcode: .configuration, sequence: 1, payload: [0,3,30,0x0f]), current: nil)
        precondition(config?.supportsPhoneFind == true && config?.supportsReliablePhoneFind == false)
        print("PASS: wire compatibility, ACK timing, concurrent deduplication, durable replay, expiry and storage failures")
    }
}
