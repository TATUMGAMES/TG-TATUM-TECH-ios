import SwiftUI
import TatumTechKit

struct ForgotPasswordView: View {
    @State private var model: ForgotPasswordModel
    @FocusState private var isEmailFocused: Bool

    init(account: AccountService) {
        _model = State(initialValue: ForgotPasswordModel(account: account))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Input your email to reset your password.")
                    .font(.body)
                    .foregroundStyle(Palette.textPrimary)
                    .padding(.vertical, Spacing.xl)

                FormTextField(title: "Email", text: $model.email.text, contentType: .username, keyboard: .emailAddress)
                    .focused($isEmailFocused)
                    .submitLabel(.send)
                    .onSubmit(submit)
                    .accessibilityIdentifier("forgotPassword.email")
                FieldError(message: "Input a valid email address.", isVisible: model.showsEmailError)

                Button(action: submit) {
                    if model.isSubmitting {
                        ProgressView().accessibilityLabel("Sending")
                    } else {
                        Text("Reset Password")
                    }
                }
                .buttonStyle(.primary)
                .disabled(!model.canSubmit)
                .padding(.top, Spacing.lg)
                .accessibilityIdentifier("forgotPassword.submit")

                if model.didSendEmail {
                    Label("Reset password email sent", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Palette.success)
                        .padding(.top, Spacing.md)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .animation(.default, value: model.didSendEmail)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            TermsAndPrivacyText()
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.xs)
                .background(Palette.surface)
        }
        .background(Palette.surface.ignoresSafeArea())
        .navigationTitle("Forgot Password")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: isEmailFocused) { wasFocused, _ in
            if wasFocused { model.email.wasEdited = true }
        }
        .onChange(of: model.didSendEmail) { _, sent in
            if sent {
                AccessibilityNotification.Announcement(String(localized: "Reset password email sent")).post()
            }
        }
        .alert($model.alert)
    }

    private func submit() {
        guard model.canSubmit else { return }
        isEmailFocused = false
        Task { await model.submit() }
    }
}
