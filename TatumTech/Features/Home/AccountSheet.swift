import SwiftUI
import TatumTechKit

/// Account menu (the side drawer): profile and info destinations, app version, and legal links.
/// Picking a destination closes the menu and opens the screen on the current tab.
struct AccountSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

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
                    menuItem("Profile", systemImage: "person.crop.circle", route: .profile, id: "menu.profile")
                    menuItem("Demographic Info", systemImage: "list.bullet.clipboard", route: .demographics, id: "menu.demographics")
                    menuItem("About Tatum Games", systemImage: "info.circle", route: .about(.about), id: "menu.about")
                    menuItem("FAQ", systemImage: "questionmark.circle", route: .about(.faq), id: "menu.faq")
                }

                #if DEBUG
                FirebaseDiagnosticsSection(diagnostics: app.dependencies.firebase)
                #endif

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
                }
            }
        }
        .tint(Palette.brandPrimaryStrong)
    }

    private func menuItem(_ title: LocalizedStringKey, systemImage: String, route: AppRoute, id: String) -> some View {
        Button {
            router.push(route)
            dismiss()
        } label: {
            Label(title, systemImage: systemImage)
                .foregroundStyle(Palette.textPrimary)
        }
        .accessibilityIdentifier(id)
    }

    private static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
}

#if DEBUG
/// Which Firebase app this build reports to. Compiled into Debug builds only.
private struct FirebaseDiagnosticsSection: View {
    let diagnostics: FirebaseDiagnostics

    var body: some View {
        Section {
            row("Environment", diagnostics.environmentName)
            row("Bundle ID", diagnostics.bundleIdentifier)
            row("Firebase app ID", diagnostics.configuration?.googleAppID ?? "None")
            row("Firebase project", diagnostics.configuration?.projectID ?? "None")
            row("Status", diagnostics.isConfigured ? "Running" : diagnostics.check.summary)
        } header: {
            Text("Firebase (Debug build only)")
        }
        .accessibilityIdentifier("menu.firebaseDiagnostics")
    }

    private func row(_ title: String, _ value: String) -> some View {
        LabeledContent(title) {
            Text(value)
                .font(.footnote.monospaced())
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }
}
#endif
