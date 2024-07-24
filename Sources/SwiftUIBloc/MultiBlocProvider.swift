/*
 See LICENSE for this package's licensing information.
*/

import SwiftUI
import Bloc

public struct MultiBlocProvider<Child: View>: View {

    @State private var reference = UUID()

    private let blocs: [BlocProvider<Never>]
    private let child: Child

    public init(_ blocs: [BlocProvider<Never>], @ViewBuilder content: () -> Child) {
        self.blocs = blocs
        child = content()
    }

    public var body: some View {
        var payload = [ObjectIdentifier: @Sendable (BlocContext) -> Sendable]()

        for bloc in blocs {
            payload.updateValue({
                switch bloc.loader {
                case .create(let create):
                    return create($0)
                case .constant(let sendable):
                    return sendable
                }
            }, forKey: bloc.id)
        }

        return child.registerMultiBlocs(payload)
    }
}
