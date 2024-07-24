/*
 See LICENSE for this package's licensing information.
*/

import SwiftUI
import Bloc

public typealias Create<T> = @Sendable (BlocContext) -> T

public struct BlocProvider<Child: View>: View {

    enum Loader {
        case create(Create<Sendable>)
        case constant(Sendable)
    }

    let id: ObjectIdentifier
    let loader: Loader
    private let child: () -> Child

    public init<Bloc>(
        create: @escaping Create<Bloc>,
        @ViewBuilder child: @escaping () -> Child
    ) where Bloc: StateStreamable {
        self.init(
            id: ObjectIdentifier(Bloc.self),
            loader: .create(create),
            child: child
        )
    }

    public init<Bloc>(
        create: @escaping Create<Bloc>
    ) where Child == Never, Bloc: StateStreamable {
        self.init(
            id: ObjectIdentifier(Bloc.self),
            loader: .create(create),
            child: { fatalError("TODO") }
        )
    }

    private init(
        id: ObjectIdentifier,
        loader: Loader,
        child: @escaping () -> Child
    ) {
        self.loader = loader
        self.child = child
        self.id = id
    }

    public static func value<Bloc>(
        value: Bloc,
        @ViewBuilder child: @escaping () -> Child
    ) -> Self where Bloc: StateStreamable {
        self.init(
            id: ObjectIdentifier(Bloc.self),
            loader: .constant(value),
            child: child
        )
    }

    public static func value<Bloc>(
        value: Bloc
    ) -> Self where Child == Never, Bloc: StateStreamable {
        self.init(
            id: ObjectIdentifier(Bloc.self),
            loader: .constant(value),
            child: { fatalError("TODO") }
        )
    }

    public var body: some View {
        child()
            .registerBloc(id: id) { context in
                return register(context)
            }
    }

    private func register(_ context: BlocContext) -> Any {
        switch loader {
        case .create(let create):
            return create(context)
        case .constant(let bloc):
            return bloc
        }
    }
}
