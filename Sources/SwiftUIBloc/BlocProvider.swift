/*
 See LICENSE for this package's licensing information.
*/

import SwiftUI
import Bloc

public typealias Create<T> = @Sendable (BlocContext) -> T

public struct BlocProvider<Bloc, Child: View>: View where Bloc: StateStreamable {

    enum Loader {
        case create(Create<Bloc>)
        case constant(Bloc)
    }

    private let loader: Loader
    private let child: () -> Child

    public init(
        create: @escaping Create<Bloc>,
        @ViewBuilder child: @escaping () -> Child
    ) {
        self.init(
            loader: .create(create),
            child: child
        )
    }

    public init(
        create: @escaping Create<Bloc>
    ) where Child == Never {
        self.init(
            loader: .create(create),
            child: { fatalError("TODO") }
        )
    }

    private init(
        loader: Loader,
        child: @escaping () -> Child
    ) {
        self.loader = loader
        self.child = child
    }

    public static func value(
        value: Bloc,
        @ViewBuilder child: @escaping () -> Child
    ) -> Self {
        self.init(
            loader: .constant(value),
            child: child
        )
    }

    public static func value(
        value: Bloc
    ) -> Self where Child == Never {
        self.init(
            loader: .constant(value),
            child: { fatalError("TODO") }
        )
    }

    public var body: some View {
        child()
            .registerBloc { context -> Bloc in
                return register(context)
            }
    }

    func register(_ context: BlocContext) -> Bloc {
        switch loader {
        case .create(let create):
            return create(context)
        case .constant(let bloc):
            return bloc
        }
    }
}
