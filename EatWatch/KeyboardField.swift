import SwiftUI

extension View {
    /// iPhone and iPad show a digit pad. Mac and watch use their own text input.
    @ViewBuilder
    func decimalField() -> some View {
        #if os(iOS)
        keyboardType(.decimalPad)
        #else
        self
        #endif
    }

    @ViewBuilder
    func numberField() -> some View {
        #if os(iOS)
        keyboardType(.numberPad)
        #else
        self
        #endif
    }
}
