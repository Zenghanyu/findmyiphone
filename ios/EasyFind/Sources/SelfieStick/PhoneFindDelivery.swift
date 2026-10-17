import Foundation

/// Durable, bounded receipts. IDs are random per physical request, so the ledger
/// does not need device identifiers or a wall-clock expiry to prevent replay.
final class PhoneFindReceiptStore {
    private struct Receipt: Codable {
        let id: UInt64
        let disposition: SelfieStickProtocol.PhoneFindDisposition
    }
    private let url: URL
    private var receipts: [Receipt]
    private let capacity = 128

    init(url: URL) {
        self.url = url
        receipts = (try? JSONDecoder().decode([Receipt].self, from: Data(contentsOf: url))) ?? []
        receipts = Array(receipts.suffix(capacity))
    }

    static func applicationStore() -> PhoneFindReceiptStore {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let url = root.appendingPathComponent("PhoneFind/receipts.json")
        #if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("-selfieReset") {
            try? FileManager.default.removeItem(at: url)
        }
        #endif
        return PhoneFindReceiptStore(url: url)
    }

    func disposition(for id: UInt64) -> SelfieStickProtocol.PhoneFindDisposition? {
        receipts.last { $0.id == id }?.disposition
    }

    func record(_ id: UInt64, disposition: SelfieStickProtocol.PhoneFindDisposition) throws {
        var updated = receipts.filter { $0.id != id }
        updated.append(Receipt(id: id, disposition: disposition))
        updated = Array(updated.suffix(capacity))
        let root = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var options: Data.WritingOptions = .atomic
        #if os(iOS)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                                             ofItemAtPath: root.path)
        options.insert(.completeFileProtectionUntilFirstUserAuthentication)
        #endif
        // Publish to memory only once the receipt is saved. No ACK if this fails.
        try JSONEncoder().encode(updated).write(to: url, options: options)
        receipts = updated
    }
}

/// Only the actual system submission can turn a request into an ACK. Duplicate
/// notifications share one in-flight operation; retries after process restart
/// use the durable receipt instead of scheduling another alarm.
@MainActor
final class PhoneFindDelivery {
    enum Result: Equatable { case handled, duplicate, inFlight, expired, retry, storageFailure }
    private let store: PhoneFindReceiptStore
    private let uptime: () -> TimeInterval
    private var deadlines: [UInt64: TimeInterval] = [:]
    private var inFlight: Set<UInt64> = []
    private var uncommitted: [UInt64: SelfieStickProtocol.PhoneFindDisposition] = [:]

    init(store: PhoneFindReceiptStore, uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.store = store
        self.uptime = uptime
    }

    func receive(_ request: SelfieStickProtocol.PhoneFindRequest,
                 submit: () async -> SelfieStickProtocol.PhoneFindDisposition?,
                 acknowledge: (SelfieStickProtocol.PhoneFindDisposition) -> Void) async -> Result {
        guard request.id != 0, (1...30).contains(request.remainingSeconds) else { return .expired }
        if let disposition = store.disposition(for: request.id) {
            acknowledge(disposition)
            return .duplicate
        }
        let now = uptime()
        // Retain expired IDs as bounded tombstones rather than renewing a TTL
        // if an old queued notification is delivered after a long suspension.
        if deadlines[request.id] == nil, deadlines.count >= 128,
           let oldest = deadlines.min(by: { $0.value < $1.value })?.key {
            deadlines.removeValue(forKey: oldest)
            uncommitted.removeValue(forKey: oldest)
        }
        let deadline = min(deadlines[request.id] ?? .infinity, now + Double(request.remainingSeconds))
        deadlines[request.id] = deadline
        guard now < deadline else { return .expired }
        guard inFlight.insert(request.id).inserted else { return .inFlight }
        defer { inFlight.remove(request.id) }
        let disposition: SelfieStickProtocol.PhoneFindDisposition
        if let accepted = uncommitted[request.id] {
            disposition = accepted
        } else {
            guard let accepted = await submit() else { return .retry }
            disposition = accepted
            uncommitted[request.id] = accepted
        }
        do { try store.record(request.id, disposition: disposition) }
        catch { return .storageFailure }
        uncommitted.removeValue(forKey: request.id)
        acknowledge(disposition)
        return .handled
    }
}
