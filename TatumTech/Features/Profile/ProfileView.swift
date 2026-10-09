import SwiftUI
import TatumTechKit

/// The on-device profile: read-only username, editable names and email, sign-out, and account
/// deletion.
struct ProfileView: View {
    @Environment(AppModel.self) private var app
    @State private var isLoading = true
    @State private var username = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var isConfirmingDeletion = false
    @State private var isDeleting = false
    @State private var alert: AlertMessage?
    @State private var saveModel = ProfileSaveModel()
    @State private var signOut = ProfileSignOutModel()

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                if isLoading {
                    Text("Loading profile...")
                } else {
                    LabeledFormField(label: "Username", text: $username, systemImage: "person.fill", isEnabled: false)
                    LabeledFormField(label: "First Name", text: $firstName, systemImage: "person.fill", contentType: .givenName,
                                     identifier: "profile.firstName")
                    LabeledFormField(label: "Last Name", text: $lastName, systemImage: "person.fill", contentType: .familyName,
                                     identifier: "profile.lastName")
                    LabeledFormField(label: "Email", text: $email, systemImage: "envelope.fill", contentType: .emailAddress,
                                     keyboard: .emailAddress, capitalization: .never, identifier: "profile.email")
                    Button("Save", action: save)
                        .buttonStyle(.primary)
                        .padding(.top, Spacing.xl)
                        .accessibilityIdentifier("profile.save")

                    // A text link rather than a button style, so it stays visually subordinate to Save.
                    Button {
                        signOut.requestSignOut()
                    } label: {
                        Text("Sign Out")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.black)
                            .padding(.horizontal, Spacing.sm)
                            .frame(minHeight: Metrics.minimumTapTarget)
                    }
                    .accessibilityIdentifier("account.signOut")
                }

                Button {
                    isConfirmingDeletion = true
                } label: {
                    Label("Delete Account", systemImage: "trash.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Palette.destructive)
                        .padding(.horizontal, Spacing.sm)
                        .frame(minHeight: Metrics.minimumTapTarget)
                }
                .padding(.top, 48)
                .padding(.bottom, 30)
                .accessibilityIdentifier("account.delete")
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.md)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.white.ignoresSafeArea())
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .disabled(progressMessage != nil)
        .overlay {
            if let progressMessage {
                ProgressView(progressMessage)
                    .tint(Palette.brandPrimaryStrong)
                    .padding(Spacing.xl)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.medium))
            }
        }
        .navigationBarBackButtonHidden(progressMessage != nil)
        .alert("Delete Account", isPresented: $isConfirmingDeletion) {
            Button("Yes", role: .destructive, action: deleteAccount)
            Button("No", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete your Tatum Tech account? This action is not reversable.")
        }
        .alert("Sign Out", isPresented: $signOut.isConfirming) {
            Button("Yes", action: confirmSignOut)
            Button("No", role: .cancel) {}
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .toast($saveModel.toast)
        .alert($alert)
        .alert($saveModel.alert, retry: save)
        .alert($signOut.alert, retry: confirmSignOut)
        .task { await load() }
    }

    /// Shown over the screen, which ignores input, while saving, deletion, or sign-out runs.
    private var progressMessage: LocalizedStringKey? {
        if isDeleting { return "Deleting account…" }
        if signOut.isSigningOut { return "Signing out…" }
        if saveModel.isSaving { return "Saving…" }
        return nil
    }

    private func confirmSignOut() {
        Task { await signOut.confirm { await app.signOut() } }
    }

    private func load() async {
        let user = await app.local.ensureUser()
        username = user.name
        firstName = user.firstName ?? ""
        lastName = user.lastName ?? ""
        email = user.email ?? ""
        isLoading = false
    }

    private func save() {
        let (first, last, mail) = (firstName, lastName, email)
        Task { await saveModel.save { await app.saveProfile(firstName: first, lastName: last, email: mail) } }
    }

    private func deleteAccount() {
        isDeleting = true
        Task {
            switch await app.deleteAccount() {
            case .deleted:
                break
            case .cancelled:
                isDeleting = false
            case let .failed(message):
                isDeleting = false
                alert = message
            }
        }
    }
}
