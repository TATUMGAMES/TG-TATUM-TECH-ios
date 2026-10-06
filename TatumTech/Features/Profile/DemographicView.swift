import SwiftUI
import TatumTechKit

/// Optional demographic answers, gated by an age notice and three consent checkboxes.
struct DemographicView: View {
    @Environment(AppModel.self) private var app
    @Environment(AppRouter.self) private var router
    @State private var showsAgeNotice = true
    @State private var info = DemographicInfo()
    @State private var ageConfirmed = false
    @State private var parentPermissionConfirmed = false
    @State private var dataUsageAcknowledged = false
    @State private var toast: ToastMessage?

    private var canSave: Bool { ageConfirmed && parentPermissionConfirmed && dataUsageAcknowledged }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Demographic Information")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Text("The information below is optional and helps us improve our events, understand attendee engagement, and prepare aggregate reporting. Providing this information is voluntary and will not affect your ability to attend or participate.")
                    .font(.caption)
                    .foregroundStyle(Palette.grey)

                ConsentToggle(isOn: $ageConfirmed, label: "I confirm that I am at least 13 years old.")
                    .padding(.top, Spacing.xxs)
                    .accessibilityIdentifier("demographics.consent.age")
                ConsentToggle(isOn: $parentPermissionConfirmed, label: "If I am under 18 years old, I confirm that I have permission from a parent or legal guardian to provide this information.")
                    .accessibilityIdentifier("demographics.consent.parent")
                Divider()

                OptionPicker(label: "Age Range", options: DemographicInfo.ageRanges, selection: $info.ageRange)
                OptionPicker(label: "Sex", options: DemographicInfo.sexOptions, selection: $info.sex)
                LabeledFormField(label: "Occupation", text: $info.occupation)
                    .onChange(of: info.occupation) { _, value in
                        if value.trimmingCharacters(in: .whitespaces).isEmpty { info.salaryRange = "" }
                    }
                if !info.occupation.trimmingCharacters(in: .whitespaces).isEmpty {
                    OptionPicker(label: "Salary Range", options: DemographicInfo.salaryRanges, selection: $info.salaryRange)
                }
                LabeledFormField(label: "School or School District", text: $info.school)

                Divider()
                    .padding(.top, Spacing.xxs)
                Text("Data Usage Acknowledgement")
                    .font(.headline)
                ConsentToggle(isOn: $dataUsageAcknowledged, label: "I understand that the information I provide may be used for event analytics, attendee research, surveys, and aggregate reporting as described in the Privacy Policy.")
                    .accessibilityIdentifier("demographics.consent.dataUsage")

                Button("Save Demographic Information", action: save)
                    .buttonStyle(.primary)
                    .disabled(!canSave)
                    .padding(.top, Spacing.xs)
                    .padding(.bottom, Spacing.xl)
                    .accessibilityIdentifier("demographics.save")
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.md)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.white.ignoresSafeArea())
        .navigationTitle("Demographic Info")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Before You Begin", isPresented: $showsAgeNotice) {
            Button("I Am 13 Or Older") {}
            Button("Cancel", role: .cancel) { router.pop() }
        } message: {
            Text("We collect optional demographic information to help improve future events, better understand attendee participation, and prepare aggregate reports. Individual responses are not publicly displayed.\n\nTo continue, you must confirm that you are at least 13 years old. If you are under 18, you should have permission from a parent or legal guardian before providing information.")
        }
        .toast($toast)
        .task {
            if let saved = await app.local.demographics() { info = saved }
        }
    }

    private func save() {
        guard canSave else { return }
        let local = app.local
        let answers = info
        Task {
            await local.saveDemographics(answers)
            toast = ToastMessage(text: "Thank you. Your information has been saved.")
        }
    }
}

private struct ConsentToggle: View {
    @Binding var isOn: Bool
    let label: String

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(alignment: .top, spacing: Spacing.sm) {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundStyle(isOn ? Palette.brandPrimaryStrong : Palette.textSecondary)
                Text(label)
                    .font(.callout)
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}

/// A read-only field that opens a menu of options.
private struct OptionPicker: View {
    let label: String
    let options: [String]
    @Binding var selection: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Palette.textSecondary)
            Menu {
                ForEach(options, id: \.self) { option in
                    Button(option) { selection = option }
                }
            } label: {
                HStack {
                    Text(selection.isEmpty ? " " : selection)
                        .foregroundStyle(Palette.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundStyle(Palette.textSecondary)
                }
                .formFieldChrome()
                .contentShape(Rectangle())
            }
            .accessibilityLabel(label)
            .accessibilityValue(selection.isEmpty ? "Not selected" : selection)
        }
    }
}
