import SwiftUI

struct PressableButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        PressableBody(configuration: configuration, pressedScale: pressedScale)
    }

    private struct PressableBody: View {
        let configuration: ButtonStyle.Configuration
        var pressedScale: CGFloat
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            configuration.label
                .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : pressedScale)
                .opacity(configuration.isPressed ? 0.88 : 1)
                .animation(
                    reduceMotion ? nil : .easeOut(duration: 0.12),
                    value: configuration.isPressed
                )
        }
    }
}
