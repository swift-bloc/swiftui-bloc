/*
 See LICENSE for this package's licensing information.
*/

import SwiftUI
import Bloc

public typealias BlocViewSelector<State, T: Equatable> = @Sendable (State) -> T

public struct BlocSelector<Bloc, State, T: Equatable, Child: View>: View where Bloc: StateStreamable<State> & AnyObject {

    private let bloc: Bloc?
    private let selector: BlocViewSelector<State, T>
    private let build: BlocViewBuilder<T, Child>

    public init(
        bloc: Bloc?,
        selector: @escaping BlocViewSelector<State, T>,
        @ViewBuilder build: @escaping BlocViewBuilder<T, Child>
    ) {
        self.bloc = bloc
        self.selector = selector
        self.build = build
    }

    public var body: some View {
        BlocSelectorBase(
            bloc: bloc,
            selector: selector,
            builder: build
        )
    }
}

private struct BlocSelectorBase<Bloc, State, T: Equatable, Child: View>: View where Bloc: StateStreamable<State> & AnyObject {

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

    private var state: T {
        if let state = _state {
            return state
        }

        let state = selector(bloc.state)
        BlocQueue.shared.addUniqueOperation(stateID) {
            _state = state
        }
        return state
    }

    private let constantBlocValue: Bloc?
    private let selector: BlocViewSelector<State, T>
    private let builder: BlocViewBuilder<T, Child>

    // MARK: - SwiftUI properties

    @SwiftUI.State private var blocID = UUID()
    @SwiftUI.State private var stateID = UUID()

    @SwiftUI.State private var _state: T?
    @SwiftUI.State private var _bloc: WeakReference<Bloc>?

    @Environment(\.blocContext) private var context

    // MARK: - Inits

    init(
        bloc: Bloc?,
        selector: @escaping BlocViewSelector<State, T>,
        @ViewBuilder builder: @escaping BlocViewBuilder<T, Child>
    ) {
        self.constantBlocValue = bloc
        self.selector = selector
        self.builder = builder
    }

    var body: some View {
        BlocListener(
              bloc: bloc,
              listener: { context, state in
                  let selectedState = selector(state)
                  if self.state != selectedState {
                      _state = selectedState
                  }
              },
              child: { builder(context, state) }
        )
    }
}
