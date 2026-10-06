import AuthenticationServices
import SwiftUI

enum AuthRoute: Hashable {
    case signIn
    case signUp
    case forgotPassword
}

/// Signed-out experience: welcome screen, then email sign-in, sign-up, or password reset.
struct AuthFlowView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        NavigationStack {
            WelcomeView(model: FederatedSignInModel(
                account: app.accountService,
                google: app.dependencies.googleSignIn
            ))
            .navigationDestination(for: AuthRoute.self) { route in
                switch route {
                case .signIn: SignInView(account: app.accountService)
                case .signUp: SignUpView(account: app.accountService)
                case .forgotPassword: ForgotPasswordView(account: app.accountService)
                }
            }
        }
        .tint(Palette.brandPrimaryStrong)
    }
}

struct WelcomeView: View {
    @Environment(AppModel.self) private var app
    @State private var model: FederatedSignInModel

    init(model: FederatedSignInModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: Spacing.xl)

            VStack(spacing: Spacing.lg) {
                Text("Let's begin your Tatum Tech experience.")
                    .font(.body)
                    .foregroundStyle(Palette.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                NavigationLink(value: AuthRoute.signIn) {
                    Text("Sign In")
                }
                .buttonStyle(.primary)
                .accessibilityIdentifier("welcome.signIn")

                NavigationLink(value: AuthRoute.signUp) {
                    Text("Sign Up")
                }
                .buttonStyle(.primary)
                .accessibilityIdentifier("welcome.signUp")

                Text("OR")
                    .font(.title3.bold())
                    .foregroundStyle(Palette.textPrimary)
                    .accessibilityHidden(true)

                Button {
                    Task {
                        if let state = await model.signInWithGoogle() { app.apply(state) }
                    }
                } label: {
                    Image("google_sign_in_button")
                        .resizable()
                        .scaledToFit()
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Sign in with Google")
                .accessibilityIdentifier("welcome.google")

                SignInWithAppleButton(.signIn) { request in
                    model.prepareAppleRequest(request)
                } onCompletion: { result in
                    Task {
                        if let state = await model.completeApple(result) { app.apply(state) }
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: Metrics.buttonHeight)
                .accessibilityIdentifier("welcome.apple")
            }
            .frame(maxWidth: Metrics.authButtonMaxWidth)

            Spacer(minLength: Spacing.xl)

            TermsAndPrivacyText()
                .padding(.bottom, Spacing.xs)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.surface.ignoresSafeArea())
        .disabled(model.isWorking)
        .overlay {
            if model.isWorking {
                ProgressView()
                    .controlSize(.large)
                    .accessibilityLabel("Signing in")
            }
        }
        .alert($model.alert)
        .toolbar(.hidden, for: .navigationBar)
    }
}
