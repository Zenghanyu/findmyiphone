import Observation
import UIKit

/// Processes locally before confirmation. The cached result owns both the
/// visible preview and the exact payload subsequently handed to the transport.
@MainActor @Observable
final class InkArtworkController {
  struct Key: Equatable {
    let revision: UUID
    let antiLost: Bool
  }

  private(set) var prepared: EFInkPreparedImage?
  private(set) var processing = false
  private(set) var error: String?
  private var key: Key?
  private var generation = 0

  func invalidate() {
    generation += 1
    key = nil
    prepared = nil
    processing = false
    error = nil
  }

  func prepare(_ image: UIImage, key: Key) {
    guard self.key != key else { return }
    invalidate()
    self.key = key
    processing = true
    let current = generation
    EFInkBridge.prepare(image, antiLost: key.antiLost) { [weak self] result, error in
      Task { @MainActor in
        guard let self, self.generation == current else { return }
        self.prepared = result
        self.processing = false
        self.error = error
      }
    }
  }
}
