import SwiftUI

/// Account menu (the Android side drawer): profile and info destinations, account deletion,
/// app version, and legal links.
struct AccountSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var isConfirmingDeletion = false
    @State private var isDeleting = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Image("tatumgames_logo")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 240)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.md)
                        .accessibilityLabel("Tatum Tech")
                        .listRowBackground(Color.clear)
                }

                Section {
                    menuLink(.profile)
                    menuLink(.demographics)
                    menuLink(.about)
                    menuLink(.faq)
                }

                Section {
                    Button(role: .destructive) {
                        isConfirmingDeletion = true
                    } label: {
                        Label("Delete Account", systemImage: "trash")
                            .foregroundStyle(Palette.error)
                    }
                    .accessibilityIdentifier("account.delete")
                }

                Section {
                    VStack(spacing: Spacing.sm) {
                        Text("Version \(Self.appVersion)")
                            .font(.footnote)
                            .foregroundStyle(Palette.textSecondary)
                        TermsAndPrivacyText()
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .disabled(isDeleting)
                }
            }
            .navigationDestination(for: PendingFeature.self) { feature in
                PendingFeatureView(feature: feature)
            }
            .disabled(isDeleting)
            .overlay {
                if isDeleting {
                    ProgressView("Deleting account.")
                        .padding(Spacing.xl)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.medium))
                }
            }
        }
        .tint(Palette.brandPrimaryStrong)
        .interactiveDismissDisabled(isDeleting)
        .alert("Delete Account", isPresented: $isConfirmingDeletion) {
            Button("Yes", role: .destructive, action: deleteAccount)
            Button("No", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete your Tatum Tech account? This action is not reversable.")
        }
    }

    private func menuLink(_ feature: PendingFeature) -> some View {
        NavigationLink(value: feature) {
            Label(feature.title, systemImage: feature.systemImage)
                .foregroundStyle(Palette.textPrimary)
        }
    }

    private func deleteAccount() {
        isDeleting = true
        Task {
            await app.deleteAccount()
        }
    }

    private static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
}
