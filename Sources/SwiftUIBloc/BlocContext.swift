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

    func register(
        _ loader: @escaping @Sendable () -> Sendable,
        id: ObjectIdentifier
    ) -> Self {
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

private struct BlocContextModifier: ViewModifier {

    @State var loaded: Sendable?

    @Environment(\.blocContext) var context
    let id: ObjectIdentifier
    let loader: @Sendable (BlocContext) -> Sendable

    func body(content: Content) -> some View {
        content
            .environment(\.blocContext, context.register({
                let bloc = loaded ?? loader(context)
                loaded = bloc
                return bloc
            }, id: id))
    }
}

extension View {

    func registerBloc(id: ObjectIdentifier, loader: @escaping @Sendable (BlocContext) -> Sendable) -> some View {
        modifier(BlocContextModifier(id: id, loader: loader))
    }
}


private struct MultiBlocContextModifier: ViewModifier {

    let payload: [ObjectIdentifier: @Sendable (BlocContext) -> Sendable]

    @Environment(\.blocContext) var context
    @State var blocs: [ObjectIdentifier: Sendable] = [:]

    func body(content: Content) -> some View {
        content.environment(\.blocContext, registerAll(context))
    }

    func registerAll(_ context: BlocContext) -> BlocContext {
        var context = context

        for key in Set(blocs.keys).subtracting(Set(payload.keys)) {
            blocs[key] = nil
        }

        for entry in payload {
            context = context.register({ [context] in
                if let entry = blocs[entry.key] {
                    return entry
                } else {
                    let bloc = entry.value(context)
                    blocs[entry.key] = bloc
                    return bloc
                }
            }, id: entry.0)
        }

        return context
    }
}

extension View {

    func registerMultiBlocs(_ payload: [ObjectIdentifier: @Sendable (BlocContext) -> Sendable]) -> some View {
        modifier(MultiBlocContextModifier(payload: payload))
    }
}
