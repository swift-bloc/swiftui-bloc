/*
 See LICENSE for this package's licensing information.
*/

import SwiftUI
import Bloc

/// Signature for the `builder` function which takes the `BuildContext` and
/// [state] and is responsible for returning a view which is to be rendered.
/// This is analogous to the `builder` function in [StreamBuilder].
public typealias BlocViewBuilder<State, Content: View> = @Sendable  (BlocViewBuilderInput<State>) -> Content

public struct BlocViewBuilderInput<State: Sendable>: Sendable {

    // MARK: - Public properties

    public let context: BlocContext
    public let state: State

    // MARK: - Inits

    init(context: BlocContext, state: State) {
        self.context = context
        self.state = state
    }
}
/// Signature for the `buildWhen` function which takes the previous `state` and
/// the current `state` and is responsible for returning a [bool] which
/// determines whether to rebuild [BlocBuilder] with the current `state`.
public typealias BlocBuilderCondition<State> = @Sendable (BlocBuilderConditionInput<State>) -> Bool

public struct BlocBuilderConditionInput<State: Sendable>: Sendable {

    // MARK: - Public properties

    public let previous: State
    public let current: State

    // MARK: - Inits

    init(previous: State, current: State) {
        self.previous = previous
        self.current = current
    }
}

public struct BlocBuilder<Bloc, State, Child: View>: View where Bloc: StateStreamable<State> & AnyObject {

    // MARK: - Private properties

    private let builder: BlocViewBuilder<State, Child>
    private let bloc: Bloc?
    private let buildWhen: BlocBuilderCondition<State>?

    // MARK: - Inits

    public init(
        @ViewBuilder builder: @escaping BlocViewBuilder<State, Child>,
        bloc: Bloc? = nil,
        buildWhen: BlocBuilderCondition<State>? = nil
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

private struct BlocBuilderBase<Bloc, State, Child: View>: View where Bloc: StateStreamable<State> & AnyObject {

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

    private var state: State {
        if let state = _state {
            return state
        }

        let state = bloc.state
        BlocQueue.shared.addUniqueOperation(stateID) {
            _state = state
        }
        return state
    }

    private let builder: BlocViewBuilder<State, Child>
    private let constantBlocValue: Bloc?
    private let buildWhen: BlocBuilderCondition<State>?

    // MARK: - SwiftUI properties

    @SwiftUI.State private var blocID = UUID()
    @SwiftUI.State private var stateID = UUID()

    @SwiftUI.State private var _state: State?
    @SwiftUI.State private var _bloc: WeakReference<Bloc>?

    @Environment(\.blocContext) private var context

    // MARK: - Inits

    init(
        builder: @escaping BlocViewBuilder<State, Child>,
        bloc: Bloc? = nil,
        buildWhen: BlocBuilderCondition<State>? = nil
    ) {
        self.builder = builder
        self.constantBlocValue = bloc
        self.buildWhen = buildWhen
    }

    // MARK: - body

    var body: some View {
        BlocListener(
            bloc: constantBlocValue,
            listener: { _state = $0 },
            listenWhen: {
                if let buildWhen = buildWhen {
                    return { buildWhen(.init(previous: $0.previous, current: $0.current)) }
                } else {
                    return nil
                }
            }(),
            child: {
                builder(.init(context: context, state: state))
            }
        )
    }
}
