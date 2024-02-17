/*
 See LICENSE for this package's licensing information.
*/

import SwiftUI
import Bloc

public struct BlocConsumer<Bloc, Child: View>: View where Bloc: StateStreamable & AnyObject {

    // MARK: - Private properties

    private let bloc: Bloc?
    private let listenWhen: BlocListenerCondition<Bloc.State>?
    private let buildWhen: BlocBuilderCondition<Bloc.State>?
    private let listener: BlocViewListener<Bloc.State>
    private let builder: BlocViewBuilder<Bloc.State, Child>

    // MARK: - SwiftUI properties

    @Environment(\.blocContext) var context

    // MARK: - Inits

    public init(
        bloc: Bloc? = nil,
        buildWhen: BlocBuilderCondition<Bloc.State>? = nil,
        listenWhen: BlocListenerCondition<Bloc.State>? = nil,
        listener: @escaping BlocViewListener<Bloc.State>,
        @ViewBuilder builder: @escaping BlocViewBuilder<Bloc.State, Child>
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
