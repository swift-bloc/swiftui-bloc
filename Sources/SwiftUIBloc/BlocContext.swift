/*
 See LICENSE for this package's licensing information.
*/

import SwiftUI

enum GenericError: Error {
    case blockNotRegistered
}

public struct BlocContext: Sendable {

    private var handlers: [ObjectIdentifier: @Sendable () -> Any] = [:]

    init() {}

    func register<B: Sendable>(loader: @escaping @Sendable () -> B) -> Self {
        let id = ObjectIdentifier(B.self)
        if handlers[id] != nil {
            fatalError("TODO: - Already registered")
        }

        var mutableSelf = self
        mutableSelf.handlers[id] = {
            loader()
        }
        return mutableSelf
    }

    public func read<B: Sendable>(_ type: B.Type = B.self) throws -> B {
        guard
            let handler = handlers[ObjectIdentifier(B.self)],
            let bloc = handler() as? B
        else { throw GenericError.blockNotRegistered }

        return bloc
    }
}

private struct BlocContextEnvironmentKey: EnvironmentKey {
    static let defaultValue = BlocContext()
}

extension EnvironmentValues {

    public internal(set) var blocContext: BlocContext {
        get { self[BlocContextEnvironmentKey.self] }
        set { self[BlocContextEnvironmentKey.self] = newValue }
    }
}

private struct BlocContextModifier<B: Sendable>: ViewModifier {

    @State var loaded: B?

    @Environment(\.blocContext) var context
    let loader: @Sendable (BlocContext) -> B

    func body(content: Content) -> some View {
        content
            .environment(\.blocContext, context.register { () -> B in
                let bloc = loaded ?? loader(context)
                loaded = bloc
                return bloc
            })
    }
}

extension View {

    func registerBloc<B: Sendable>(_ loader: @escaping @Sendable (BlocContext) -> B) -> some View {
        modifier(BlocContextModifier(loader: loader))
    }
}
