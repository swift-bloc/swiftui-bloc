/*
 See LICENSE for this package's licensing information.
*/

import SwiftUI

struct Box<Value: Sendable>: Sendable {

    private class Storage: @unchecked Sendable {

        // MARK: - Internal properties

        var value: Value {
            get { lock.withLock { _value } }
            set { lock.withLockVoid { _value = newValue } }
        }

        private let lock = Lock()
        private var _value: Value

        // MARK: - Inits

        init(_ value: Value) {
            _value = value
        }
    }

    // MARK: - Internal properties

    var value: Value {
        get { storage.value }
        nonmutating
        set { storage.value = newValue }
    }

    // MARK: - Internal properties

    private let storage: Storage

    // MARK: - Internal properties

    init(_ value: Value) {
        storage = .init(value)
    }
}
