/*
 See LICENSE for this package's licensing information.
*/

import SwiftUI
import Bloc

public struct BlocConsumer<Bloc, State, Child: View>: View where Bloc: StateStreamable<State> & AnyObject {

    // MARK: - Private properties

    private let bloc: Bloc?
    private let listenWhen: BlocListenerCondition<State>?
    private let buildWhen: BlocBuilderCondition<State>?
    private let listener: BlocViewListener<State>
    private let builder: BlocViewBuilder<State, Child>

    // MARK: - SwiftUI properties

    @Environment(\.blocContext) var context

    // MARK: - Inits

    public init(
        bloc: Bloc? = nil,
        buildWhen: BlocBuilderCondition<State>? = nil,
        listenWhen: BlocListenerCondition<State>? = nil,
        listener: @escaping BlocViewListener<State>,
        @ViewBuilder builder: @escaping BlocViewBuilder<State, Child>
    ) {
        self.bloc = bloc
        self.buildWhen = buildWhen
        self.listenWhen = listenWhen
        self.listener = listener
        self.builder = builder
    }

    // MARK: - body

    public var body: some View {
        BlocBuilder(
            bloc: bloc,
            buildWhen: { previous, current in
                if listenWhen?(previous, current) ?? true {
                    listener(context, current)
                }

                return buildWhen?(previous, current) ?? true
            },
            builder: builder
        )
    }
}
