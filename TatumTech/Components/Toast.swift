import SwiftUI

/// A short message that slides up from the bottom and hides itself, like a snackbar.
struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
}

extension View {
    func toast(_ message: Binding<ToastMessage?>) -> some View {
        modifier(ToastModifier(message: message))
    }
}

private struct ToastModifier: ViewModifier {
    @Binding var message: ToastMessage?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let message {
                    Text(message.text)
                        .font(.callout)
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: Radius.small).fill(Color(white: 0.2)))
                        .padding(Spacing.md)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .accessibilityAddTraits(.isStaticText)
                        .task(id: message.id) {
                            AccessibilityNotification.Announcement(message.text).post()
                            try? await Task.sleep(for: .seconds(3))
                            if self.message?.id == message.id { self.message = nil }
                        }
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: message)
    }
}
