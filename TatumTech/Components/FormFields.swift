import SwiftUI
import UIKit

/// Rounded single-line text input used by the auth forms.
struct FormTextField: View {
    let title: LocalizedStringKey
    @Binding var text: String
    var contentType: UITextContentType?
    var keyboard: UIKeyboardType = .default

    var body: some View {
        TextField(title, text: $text)
            .textContentType(contentType)
            .keyboardType(keyboard)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .formFieldChrome()
    }
}

/// Password input with a Show/Hide toggle.
struct FormSecureField: View {
    let title: LocalizedStringKey
    @Binding var text: String
    @Binding var isRevealed: Bool
    var contentType: UITextContentType = .password

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Group {
                if isRevealed {
                    TextField(title, text: $text)
                } else {
                    SecureField(title, text: $text)
                }
            }
            .textContentType(contentType)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            Button {
                isRevealed.toggle()
            } label: {
                isRevealed ? Text("Hide") : Text("Show")
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Palette.textPrimary)
            .frame(minWidth: Metrics.minimumTapTarget, minHeight: Metrics.minimumTapTarget)
            .accessibilityLabel(isRevealed ? Text("Hide password") : Text("Show password"))
        }
        .formFieldChrome()
    }
}

/// Validation message under a field. Keeps its space while hidden so the form doesn't jump.
struct FieldError: View {
    let message: LocalizedStringKey
    let isVisible: Bool

    var body: some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(Palette.error)
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(isVisible ? 1 : 0)
            .accessibilityHidden(!isVisible)
            .padding(.top, Spacing.xxs)
    }
}

private extension View {
    func formFieldChrome() -> some View {
        padding(.horizontal, Spacing.md)
            .frame(minHeight: Metrics.buttonHeight)
            .background(
                RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                    .fill(Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                    .strokeBorder(Palette.divider, lineWidth: 1)
            )
    }
}
