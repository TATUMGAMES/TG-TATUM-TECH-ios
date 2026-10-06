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

/// Labeled single-line field with an optional leading icon, for profile-style forms.
struct LabeledFormField: View {
    let label: LocalizedStringKey
    @Binding var text: String
    var systemImage: String?
    var contentType: UITextContentType?
    var keyboard: UIKeyboardType = .default
    var capitalization: TextInputAutocapitalization = .words
    var isEnabled = true
    var errorMessage: LocalizedStringKey?
    /// Applied to the text field itself so UI tests find the input, not its label.
    var identifier: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(errorMessage == nil ? Palette.textSecondary : Palette.error)
            HStack(spacing: Spacing.sm) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .foregroundStyle(Palette.textSecondary)
                        .accessibilityHidden(true)
                }
                TextField(label, text: $text)
                    .textContentType(contentType)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(capitalization)
                    .autocorrectionDisabled()
                    .disabled(!isEnabled)
                    .foregroundStyle(isEnabled ? Palette.textPrimary : Palette.textSecondary)
                    .accessibilityIdentifier(identifier)
            }
            .formFieldChrome()
            .overlay(
                RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                    .strokeBorder(Palette.error, lineWidth: errorMessage == nil ? 0 : 1.5)
            )
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(Palette.error)
            }
        }
    }
}

extension View {
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
