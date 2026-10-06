import SwiftUI
import TatumTechKit

struct SignInView: View {
    private enum Field: Hashable { case email, password }

    @Environment(AppModel.self) private var app
    @State private var model: SignInModel
    @FocusState private var focus: Field?

    init(account: AccountService) {
        _model = State(initialValue: SignInModel(account: account))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Welcome back! Sign in to continue.")
                    .font(.body)
                    .foregroundStyle(Palette.textPrimary)
                    .padding(.top, Spacing.xl)
                    .padding(.bottom, Spacing.xl)

                FormTextField(title: "Email", text: $model.email.text, contentType: .username, keyboard: .emailAddress)
                    .focused($focus, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focus = .password }
                    .accessibilityIdentifier("signIn.email")
                FieldError(message: "Input a valid email address.", isVisible: model.showsEmailError)

                FormSecureField(title: "Password", text: $model.password.text, isRevealed: $model.isPasswordRevealed)
                    .focused($focus, equals: .password)
                    .submitLabel(.go)
                    .onSubmit(submit)
                    .padding(.top, Spacing.md)
                    .accessibilityIdentifier("signIn.password")
                FieldError(
                    message: "Password must be at minimum 6 characters with 1 uppercase letter and 1 special character.",
                    isVisible: model.showsPasswordError
                )

                Button(action: submit) {
                    if model.isSubmitting {
                        ProgressView().accessibilityLabel("Signing in")
                    } else {
                        Text("Sign In")
                    }
                }
                .buttonStyle(.primary)
                .disabled(!model.canSubmit)
                .padding(.top, Spacing.lg)
                .accessibilityIdentifier("signIn.submit")

                HStack {
                    Spacer()
                    NavigationLink("Forgot Password", value: AuthRoute.forgotPassword)
                        .foregroundStyle(Palette.textPrimary)
                        .frame(minHeight: Metrics.minimumTapTarget)
                }
                .padding(.top, Spacing.sm)
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
        .navigationTitle("Sign In")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: focus) { previous, _ in
            switch previous {
            case .email: model.email.wasEdited = true
            case .password: model.password.wasEdited = true
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
