/*
 See LICENSE for this package's licensing information.
*/

import SwiftUI
import Bloc

public typealias BlocViewListener<State: Sendable> = @Sendable (_ context: BlocContext, _ state: State) -> Void

/// Signature for the `listenWhen` function which takes the previous `state`
/// and the current `state` and is responsible for returning a [bool] which
/// determines whether or not to call [BlocViewListener] of [BlocListener]
/// with the current `state`.
public typealias BlocListenerCondition<State: Sendable> = @Sendable (_ previous: State, _ current: State) -> Bool

public struct BlocListener<Bloc, State, Child: View>: View where Bloc: StateStreamable<State> & AnyObject {

    // MARK: - Private properties

    private let bloc: Bloc?
    private let listener: BlocViewListener<State>
    private let listenWhen: BlocListenerCondition<State>?
    private let child: () -> Child

    // MARK: - Inits

    public init(
        bloc: Bloc? = nil,
        listener: @escaping BlocViewListener<State>,
        listenWhen: BlocListenerCondition<State>? = nil,
        @ViewBuilder child: @escaping () -> Child
    ) {
        self.bloc = bloc
        self.listener = listener
        self.listenWhen = listenWhen
        self.child = child
    }

    public init(
        bloc: Bloc? = nil,
        listener: @escaping BlocViewListener<State>,
        listenWhen: BlocListenerCondition<State>? = nil
    ) where Child == Never {
        self.bloc = bloc
        self.listener = listener
        self.listenWhen = listenWhen
        self.child = {
            fatalError("\(Self.self) used outside of MultiBlocListener must specify a child")
        }
    }

    // MARK: - body

    public var body: some View {
        BlocListenerBase(
            bloc: bloc,
            listener: listener,
            listenWhen: listenWhen,
            child: child
        )
    }
}

struct WeakReference<V: AnyObject> {

    private(set) weak var value: V?

    init(_ value: V) {
        self.value = value
    }
}

struct BlocListenerBase<Bloc, State, Child: View>: View where Bloc: StateStreamable<State> & AnyObject {

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
                _previousState = nil
                _bloc = .init(bloc)
            }
            return bloc
        } catch {
            fatalError(error.localizedDescription)
        }
    }

    private var previousState: State {
        if let previousState = _previousState {
            return previousState
        }

        let previousState = bloc.state
        BlocQueue.shared.addUniqueOperation(previousStateID) {
            _previousState = previousState
        }
        return previousState
    }

    private let constantBlocValue: Bloc?
    private let listener: BlocViewListener<State>
    private let listenWhen: BlocListenerCondition<State>?
    private let child: () -> Child

    // MARK: - SwiftUI properties

    @SwiftUI.State private var streamID = UUID()
    @SwiftUI.State private var blocID = UUID()
    @SwiftUI.State private var previousStateID = UUID()

    @SwiftUI.State private var runningTask: Task<Void, Never>?

    @SwiftUI.State private var _bloc: WeakReference<Bloc>?
    @SwiftUI.State private var _previousState: State?

    @Environment(\.blocContext) private var context

    // MARK: - Inits

    init(
        bloc: Bloc?,
        listener: @escaping BlocViewListener<State>,
        listenWhen: BlocListenerCondition<State>?,
        child: @escaping () -> Child
    ) {
        self.constantBlocValue = bloc
        self.listener = listener
        self.listenWhen = listenWhen
        self.child = child
    }

    // MARK: - body

    var body: some View {
        ComplexOperationView<Child> {
            if runningTask == nil {
                BlocQueue.shared.addUniqueOperation(streamID) {
                    runningTask = Task {
                        while true {
                            do {
                                for try await state in bloc.stream {
                                    if listenWhen?(previousState, state) ?? true {
                                        listener(context, state)
                                    }

                                    _previousState = state
                                }
                            } catch {}
                        }
                    }
                }
            }

            return child()
        }
    }
}

struct ComplexOperationView<Child: View>: View {

    private let child: () -> Child

    init(_ child: @escaping () -> Child) {
        self.child = child
    }

    var body: some View {
        child()
    }
}

class BlocQueue: @unchecked Sendable {

    typealias Operation = @MainActor @Sendable () -> Void

    static let shared = BlocQueue()

    private let lock = Lock()

    private var _isRunning = false
    private var _stack: [UUID] = []
    private var _operations: [UUID: Operation] = [:]

    func addUniqueOperation(_ seed: UUID, block: @escaping Operation) {
        lock.withLockVoid {
            if _stack.contains(seed) {
                return
            }

            _stack.insert(seed, at: .zero)
            _operations[seed] = block

            if !_isRunning {
                _isRunning = true
                Task { @MainActor in
                    executeAllOperations()
                }
            }
        }
    }

    @MainActor
    private func executeAllOperations() {
        while let operation = lock.withLock({ () -> Operation? in
            guard
                _isRunning,
                let seed = _stack.popLast(),
                let operation = _operations[seed]
            else {
                _isRunning = false
                return nil
            }

            _operations[seed] = nil
            return operation
        }) { operation() }
    }
}
