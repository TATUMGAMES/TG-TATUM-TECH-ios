import SwiftUI
import TatumTechKit

struct SignUpView: View {
    private enum Field: Hashable { case email, password, confirmation }

    @Environment(AppModel.self) private var app
    @State private var model: SignUpModel
    @FocusState private var focus: Field?

    init(account: AccountService, analytics: AnalyticsService = .disabled) {
        _model = State(initialValue: SignUpModel(account: account, analytics: analytics))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Create your account.")
                    .font(.body)
                    .foregroundStyle(Palette.textPrimary)
                    .padding(.vertical, Spacing.xl)

                FormTextField(title: "Email", text: $model.email.text, contentType: .username, keyboard: .emailAddress)
                    .focused($focus, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focus = .password }
                    .accessibilityIdentifier("signUp.email")
                FieldError(message: "Input a valid email address.", isVisible: model.showsEmailError)

                FormSecureField(
                    title: "Password",
                    text: $model.password.text,
                    isRevealed: $model.isPasswordRevealed,
                    contentType: .newPassword
                )
                .focused($focus, equals: .password)
                .submitLabel(.next)
                .onSubmit { focus = .confirmation }
                .padding(.top, Spacing.md)
                .accessibilityIdentifier("signUp.password")
                FieldError(
                    message: "Password must be at minimum 6 characters with 1 uppercase letter and 1 special character.",
                    isVisible: model.showsPasswordError
                )

                FormSecureField(
                    title: "Confirm Password",
                    text: $model.confirmation.text,
                    isRevealed: $model.isConfirmationRevealed,
                    contentType: .newPassword
                )
                .focused($focus, equals: .confirmation)
                .submitLabel(.go)
                .onSubmit(submit)
                .padding(.top, Spacing.md)
                .accessibilityIdentifier("signUp.confirmation")
                FieldError(message: "Passwords do not match.", isVisible: model.showsConfirmationError)

                Button(action: submit) {
                    if model.isSubmitting {
                        ProgressView().accessibilityLabel("Creating account")
                    } else {
                        Text("Sign Up")
                    }
                }
                .buttonStyle(.primary)
                .disabled(!model.canSubmit)
                .padding(.top, Spacing.lg)
                .accessibilityIdentifier("signUp.submit")
            }
            .padding(.horizontal, Spacing.lg)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            TermsAndPrivacyText()
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.xs)
                .background(Palette.surface)
        }
        .background(Palette.surface.ignoresSafeArea())
        .navigationTitle("Sign Up")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: focus) { previous, _ in
            switch previous {
            case .email: model.email.wasEdited = true
            case .password: model.password.wasEdited = true
            case .confirmation: model.confirmation.wasEdited = true
            case nil: break
            }
        }
        .alert($model.alert)
    }

    private func submit() {
        guard model.canSubmit else { return }
        focus = nil
        Task {
            if let state = await model.submit() { app.apply(state) }
        }
    }
}
