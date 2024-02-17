/*
 See LICENSE for this package's licensing information.
*/

import SwiftUI

struct Lock: Sendable {

    // MARK: - Internal properties

    private let _lock = NSLock()

    // MARK: - Internal properties

    init() {}

    // MARK: - Internal methods

    func lock() {
        _lock.lock()
    }

    func unlock() {
        _lock.unlock()
    }

    func withLockVoid(_ block: @Sendable () throws -> Void) rethrows {
        defer { unlock() }
        lock()
        try block()
    }

    func withLock<V>(_ block: @Sendable () throws -> V) rethrows -> V {
        defer { unlock() }
        lock()
        return try block()
    }
}
