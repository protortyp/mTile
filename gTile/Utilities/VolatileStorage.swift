import Foundation

/// Provides a volatile storage for values of type T. The store
/// automatically clears the value after a specified duration.
final class VolatileStorage<T> {
    private let lifetime: TimeInterval
    private var stored: T?
    private var timer: Timer?

    /// Creates a timeout-based volatile store.
    ///
    /// - Parameter lifetime: The duration (in seconds) that the store will hold its value.
    init(lifetime: TimeInterval) {
        self.lifetime = lifetime
        self.stored = nil
    }

    deinit {
        timer?.invalidate()
    }

    /// A volatile value that is automatically reset to nil after the lifetime.
    var store: T? {
        get { stored }
        set {
            timer?.invalidate()
            stored = newValue
            if newValue != nil {
                timer = Timer.scheduledTimer(withTimeInterval: lifetime, repeats: false) { [weak self] _ in
                    self?.stored = nil
                }
            }
        }
    }
}
