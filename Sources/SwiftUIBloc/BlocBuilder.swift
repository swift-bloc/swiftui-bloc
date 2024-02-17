/*
 See LICENSE for this package's licensing information.
*/

import SwiftUI
import Bloc

/// Signature for the `builder` function which takes the `BuildContext` and
/// [state] and is responsible for returning a view which is to be rendered.
/// This is analogous to the `builder` function in [StreamBuilder].
public typealias BlocViewBuilder<State, Content: View> = @Sendable  (_ context: BlocContext, _ state: State) -> Content

//public struct BlocViewBuilderInput<State: Sendable>: Sendable {
//
//    // MARK: - Public properties
//
//    public let context: BlocContext
//    public let state: State
//
//    // MARK: - Inits
//
//    init(context: BlocContext, state: State) {
//        self.context = context
//        self.state = state
//    }
//}

/// Signature for the `buildWhen` function which takes the previous `state` and
/// the current `state` and is responsible for returning a [bool] which
/// determines whether to rebuild [BlocBuilder] with the current `state`.
public typealias BlocBuilderCondition<State> = @Sendable (_ previous: State, _ current: State) -> Bool

public struct BlocBuilder<Bloc, Child: View>: View where Bloc: StateStreamable & AnyObject {

    // MARK: - Private properties

    private let builder: BlocViewBuilder<Bloc.State, Child>
    private let bloc: Bloc?
    private let buildWhen: BlocBuilderCondition<Bloc.State>?

    // MARK: - Inits

    public init(
        bloc: Bloc? = nil,
        buildWhen: BlocBuilderCondition<Bloc.State>? = nil,
        @ViewBuilder builder: @escaping BlocViewBuilder<Bloc.State, Child>
    ) {
        self.builder = builder
        self.bloc = bloc
        self.buildWhen = buildWhen
    }

    // MARK: - body

    public var body: some View {
        BlocBuilderBase(
            builder: builder,
            bloc: bloc,
            buildWhen: buildWhen
        )
    }
}

private struct BlocBuilderBase<Bloc, Child: View>: View where Bloc: StateStreamable & AnyObject {

    // MARK: - Private properties

    private var bloc: Bloc {
        if let bloc = constantBlocValue {
            return bloc
        }

        if let bloc = _bloc?.value {
            return bloc
        }

        do {
            let bloc = try context.read(Bloc.self)
            BlocQueue.shared.addUniqueOperation(blocID) {
                _state = nil
                _bloc = .init(bloc)
            }
            return bloc
        } catch {
            fatalError(error.localizedDescription)
        }
    }

    private var state: Bloc.State {
        if let state = _state {
            return state
        }

        let state = bloc.state
        BlocQueue.shared.addUniqueOperation(stateID) {
            _state = state
        }
        return state
    }

    private let constantBlocValue: Bloc?
    private let buildWhen: BlocBuilderCondition<Bloc.State>?
    private let builder: BlocViewBuilder<Bloc.State, Child>

    // MARK: - SwiftUI properties

    @State private var blocID = UUID()
    @State private var stateID = UUID()

    @State private var _state: Bloc.State?
    @State private var _bloc: WeakReference<Bloc>?

    @Environment(\.blocContext) private var context

    // MARK: - Inits

    init(
        builder: @escaping BlocViewBuilder<Bloc.State, Child>,
        bloc: Bloc? = nil,
        buildWhen: BlocBuilderCondition<Bloc.State>? = nil
    ) {
        self.builder = builder
        self.constantBlocValue = bloc
        self.buildWhen = buildWhen
    }

    // MARK: - body

    var body: some View {
        BlocListener(
            bloc: bloc,
            listener: { _state = $1 },
            listenWhen: buildWhen,
            child: {
                builder(context, state)
            }
        )
    }
}
