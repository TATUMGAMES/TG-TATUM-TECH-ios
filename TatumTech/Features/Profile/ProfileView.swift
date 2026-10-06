import SwiftUI
import TatumTechKit

/// The on-device profile: read-only username, editable names and email, and account deletion.
struct ProfileView: View {
    @Environment(AppModel.self) private var app
    @State private var isLoading = true
    @State private var username = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var toast: ToastMessage?
    @State private var isConfirmingDeletion = false
    @State private var isDeleting = false

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
        .disabled(isDeleting)
        .overlay {
            if isDeleting {
                ProgressView("Deleting account…")
                    .tint(Palette.brandPrimaryStrong)
                    .padding(Spacing.xl)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.medium))
            }
        }
        .navigationBarBackButtonHidden(isDeleting)
        .alert("Delete Account", isPresented: $isConfirmingDeletion) {
            Button("Yes", role: .destructive, action: deleteAccount)
            Button("No", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete your Tatum Tech account? This action is not reversable.")
        }
        .toast($toast)
        .task { await load() }
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
        let local = app.local
        let analytics = app.analytics
        let (first, last, mail) = (firstName, lastName, email)
        Task {
            let changed = await local.updateProfile(firstName: first, lastName: last, email: mail)
            changed.forEach { analytics.log(.updateProfile(field: $0)) }
            await app.refreshLocalUser()
            toast = ToastMessage(text: "Profile updated successfully!")
        }
    }

    private func deleteAccount() {
        isDeleting = true
        Task { await app.deleteAccount() }
    }
}
